//
//  File.swift
//  
//
//  Created by Connor Barnes on 9/13/20.
//

import Foundation
import Socket

/// A class for communicating with an instrumnet over TCP-IP.
public final class TCPIPCommunicator {
	/// The socket used for communicating with the instrument.
	internal let socket: Socket
	/// Attributes to control the communication with the instrument.
	public var attributes = CommunicatorAttributes()
	/// Tries to create an instance from the specified address, and port of the instrument. A timeout value must also be specified.
	///
	/// - Parameters:
	///   - address: The IPV4 address of the instrument in dot notation.
	///   - port: The port of the instrument.
	///   - timeout: The maximum time to wait before timing out when communicating with the instrument.
	///
	/// - Throws: An error if a socket could not be created, connected, or configured properly.
	public init(address: String, port: Int, timeout: TimeInterval) throws {
		do {
			// TODO: Support IVP6 addresses (family: .net6)
			socket = try Socket.create(family: .inet, type: .stream, proto: .tcp)
		} catch { throw Error.couldNotCreateSocket }
		
		// TODO: XPSQ8 sent data in packets of 1024. What size packets does VISA use?
		socket.readBufferSize = 1024
		
		do {
			// TODO: We might need to specify a timeout value here. It says adding a timeout can put it into non-blocking mode, and I'm not sure What that will do.
			try socket.connect(to: address, port: Int32(port))
		} catch { throw Error.couldNotConnect }
		
		do {
			// Timeout is set as an integer in milliseconds, but it is clearer to pass in a TimeInterval into the function because TimeInterval is used
			// thoughout Foundation to represent time in seconds.
			let timeoutInMilliseconds = UInt(timeout * 1_000.0)
			try socket.setReadTimeout(value: timeoutInMilliseconds)
			try socket.setWriteTimeout(value: timeoutInMilliseconds)
		} catch { throw Error.couldNotSetTimeout }
		
		do {
			// We want to user to manage multithreding, so use blocking.
			try socket.setBlocking(mode: true)
		} catch { throw Error.couldNotEnableBlocking }
	}
	
	deinit {
		// Close the connection to the socket because we will no longer need it.
		socket.close()
	}
}

// MARK: Communicator
extension TCPIPCommunicator: Communicator {
	public func read(
		until terminator: String,
		strippingTerminator: Bool,
		encoding: String.Encoding,
		chunkSize: Int
	) throws -> String {
		// The message may not fit in a single chunk. To overcome this, we continue to request data until we are at the end of the message.
		// Continue until `string` ends in the terminator.
		var string = String()
		var chunk = Data(capacity: chunkSize)
		
		socket.readBufferSize = chunkSize
		
		repeat {
			do {
				let bytesRead = try socket.read(into: &chunk)
				
				guard let substring = String(bytes: chunk[..<bytesRead], encoding: encoding)
				else {
					throw Error.couldNotDecode
				}
				
				string += substring
				
				if bytesRead == 0 {
					// No more data to read (even if we aren't at the terminator)
					if string.count == 0 {
						// No data read at all
						throw Error.failedReadOperation
					}
					
					break
				}
			}
			// TODO: don't check the whole string for containing the terminator, only check the last chunk and enough characters before in case the terminator is split over multiple chunks
		} while !string.contains(terminator)
		
		if let terminatorRange = string.range(of: terminator, options: .backwards) {
			if strippingTerminator {
				return String(string[..<terminatorRange.lowerBound])
			} else {
				return String(string[..<terminatorRange.upperBound])
			}
		}
		
		return string
	}
	
	public func readBytes(_ count: Int, chunkSize: Int) throws -> Data {
		var data = Data(capacity: max(count, chunkSize))
		var chunk = Data(capacity: chunkSize)
		
		socket.readBufferSize = chunkSize
		
		repeat {
			do {
				let bytesRead = try socket.read(into: &chunk)
				
				data.append(chunk)
				
				if bytesRead == 0 {
					// No more data to read
					return data
				}
			}
		} while data.count < count
		
		return data[..<count]
	}
	
	public func readBytes(
		until terminator: Data,
		strippingTerminator: Bool,
		chunkSize: Int, maxBytes: Int?
	) throws -> Data {
		var data = Data(capacity: max(maxBytes ?? chunkSize, chunkSize))
		var chunk = Data(capacity: chunkSize)
		
		socket.readBufferSize = chunkSize
		
		repeat {
			do {
				let bytesRead = try socket.read(into: &chunk)
				
				data.append(chunk)
				
				if bytesRead == 0 {
					// No more data to read (even if we aren't at the terminator)
					return data
				}
			}
			// TODO: Don't need to search all of the held data, only need to seach the last chunk and some extra in case the terminator data falls over multiple chunks.
		} while data.range(of: terminator, options: .backwards) == nil
			&& data.count < (maxBytes ?? .max)
		
		if let range = data.range(of: terminator, options: .backwards) {
			let distance = data.distance(
				from: data.startIndex,
				to: strippingTerminator ? range.startIndex : range.endIndex)
			let endIndex = min(maxBytes ?? .max, distance)
			return data[..<endIndex]
		}
		
		if data.count > (maxBytes ?? .max) {
			return data[..<maxBytes!]
		}
		
		return data
	}
	
	public func write(_ string: String,
										appending terminator: String?,
										encoding: String.Encoding
	) throws {
		try (string + (terminator ?? ""))
			.cString(using: encoding)?
			.withUnsafeBufferPointer() { buffer -> () in
				// The C String includes a null terminated byte -- we will discard this
				try socket.write(from: buffer.baseAddress!, bufSize: buffer.count - 1)
			}
	}
	
	public func writeBytes(_ data: Data, appending terminator: Data?) throws {
		let data = data + (terminator ?? Data())
		try socket.write(from: data)
	}
}

// MARK:- Error
extension TCPIPCommunicator {
	/// An error associated with a `TCPIPCommunicator`.
	///
	/// - `couldNotCreateSocket`: The socket to communicate with the instrument could not be created.
	/// - `couldNotConnect`: The instrument could not be connected to. The instrument may not be connected, or could have a different address/port than the one specified.
	/// - `couldNotSetTimeout`: The timeout value could not be set.
	/// - `couldNotEnableBlocking`: The socket was unable to enable blocking.
	/// - `failedWriteOperation`: The communicator could not write to the instrument.
	/// - `failedReadOperation`: The communicator could not read from the instrument.
	/// - `couldNotDecode`: The communicator could not decode the data sent from the instrument.
	public enum Error: Swift.Error {
		case couldNotCreateSocket
		case couldNotConnect
		case couldNotSetTimeout
		case couldNotEnableBlocking
		case failedWriteOperation
		case failedReadOperation
		case couldNotDecode
	}
}

// MARK: Error Descriptions
extension TCPIPCommunicator.Error {
	public var localizedDescription: String {
		switch self {
		case .couldNotConnect:
			return "Could not connect"
		case .couldNotCreateSocket:
			return "Could not create socket"
		case .couldNotSetTimeout:
			return "Could not set timeout"
		case .couldNotEnableBlocking:
			return "Could not enable blocking"
		case .failedWriteOperation:
			return "Failed write operation"
		case .failedReadOperation:
			return "Failed read operation"
		case .couldNotDecode:
			return "Could not decode"
		}
	}
}
