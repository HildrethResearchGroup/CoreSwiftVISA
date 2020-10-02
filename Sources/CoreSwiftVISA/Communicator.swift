//
//  File.swift
//  
//
//  Created by Connor Barnes on 9/13/20.
//

import Foundation

/// A channel to communicate to and from an NI-VISA instrument.
public protocol Communicator {
	/// Communication attributes, such as terminators and encodings.
	var attributes: CommunicatorAttributes { get set }
	
	/// Reads string data from the device until the terminator is reached.
	/// - Parameters:
	///   - terminator: The string to end reading at.
	///   - strippingTerminator: If `true`, the terminator is stripped from the string before being returned, otherwise the string is returned with the terminator at the end.
	///   - encoding: The encoding used to encode the string.
	///   - chunkSize: The number of bytes to read into a buffer at a time.
	/// - Throws: If the device could not be read from.
	/// - Returns: The string read from the device.
	func read(
		until terminator: String,
		strippingTerminator: Bool,
		encoding: String.Encoding,
		chunkSize: Int
	) throws -> String
	
	/// Reads the given number of bytes from the device.
	/// - Parameters:
	///   - count: The number of bytes to read.
	///   - chunkSize: The number of bytes to read into a buffer at a time.
	/// - Throws: If the device could not be read from.
	/// - Returns: The bytes read from the device.
	func readBytes(_ count: Int, chunkSize: Int) throws -> Data
	
	/// Reads bytes from the device until the given sequence of data is reached.
	/// - Parameters:
	///   - terminator: The byte sequence to end reading at.
	///   - strippingTerminator: If `true`, the terminator is stripped from the data before being returned, otherwise the data is returned with the terminator at the end.
	///   - chunkSize: The number of bytes to read into a buffer at a time.
	///   - maxBytes: The maximum number of bytes to read.
	/// - Throws: If the device could not be read from.
	/// - Returns: The bytes read from the device.
	func readBytes(
		until terminator: Data,
		strippingTerminator: Bool,
		chunkSize: Int,
		maxBytes: Int?
	) throws -> Data
	
	/// Writes a string to the device.
	/// - Parameters:
	///   - string: The string to write to the device.
	///   - terminator: The terminator to add to the end of `string`.
	///   - encoding: The method to encode the string with.
	/// - Throws: If the device could not be written to.
	func write(
		_ string: String,
		appending terminator: String?,
		encoding: String.Encoding
	) throws
	
	/// Writes bytes to the device.
	/// - Parameters:
	///   - bytes: The data to write to the device.
	///   - terminator: The sequence of bytes to append to the end of `bytes`.
	/// - Throws: If the device could not be written to.
	func writeBytes(_: Data, appending terminator: Data?) throws
}

extension Communicator {
	/// Reads string data from the device until the terminator is reached.
	/// - Parameters:
	///   - terminator: The string to end reading at. By default, or if `nil`, `attributes.readTerminator` is used.
	///   - strippingTerminator: If `true`, the terminator is stripped from the string before being returned, otherwise the string is returned with the terminator at the end. `true` by default.
	///   - encoding: The encoding used to encode the string. By default, or if `nil`, `attributes.encoding` is used.
	///   - chunkSize: The number of bytes to read into a buffer at a time. By default, or if `nil`, `attributes.chunkSize` is used.
	/// - Throws: If the device could not be read from.
	/// - Returns: The string read from the device.
	func read(
		until terminator: String? = nil,
		strippingTerminator: Bool = true,
		encoding: String.Encoding? = nil,
		chunkSize: Int? = nil
	) throws -> String {
		return try read(
			until: terminator ?? attributes.readTerminator,
			strippingTerminator: strippingTerminator,
			encoding: encoding ?? attributes.encoding,
			chunkSize: chunkSize ?? attributes.chunkSize)
	}
	
	/// Reads the given number of bytes from the device.
	/// - Parameters:
	///   - count: The number of bytes to read.
	///   - chunkSize: The number of bytes to read into a buffer at a time. By default, or if `nil`, `attributes.chunkSize` is used.
	/// - Throws: If the device could not be read from.
	/// - Returns: The bytes read from the device.
	func readBytes(_ count: Int, chunkSize: Int? = nil) throws -> Data {
		return try readBytes(count, chunkSize: chunkSize ?? attributes.chunkSize)
	}
	
	/// Reads bytes from the device until the given sequence of data is reached.
	/// - Parameters:
	///   - terminator: The byte sequence to end reading at. By default, or if `nil`, `attributes.readTerminator` is used.
	///   - strippingTerminator: If `true`, the terminator is stripped from the data before being returned, otherwise the data is returned with the terminator at the end. `true` by default.
	///   - chunkSize: The number of bytes to read into a buffer at a time. By default, or if `nil`, `attributes.chunkSize` is used.
	///   - maxBytes: The maximum number of bytes to read. `nil` by default.
	/// - Throws: If the device could not be read from.
	/// - Returns: The bytes read from the device.
	func readBytes(
		until terminator: Data? = nil,
		strippingTerminator: Bool = true,
		chunkSize: Int? = nil,
		maxBytes: Int? = nil)
	throws -> Data {
		guard let terminator = terminator ??
						attributes.readTerminator.data(using: attributes.encoding) else {
			throw CommunicatorError.couldNotEncode
		}
		
		return try readBytes(
			until: terminator,
			strippingTerminator: strippingTerminator,
			chunkSize: chunkSize ?? attributes.chunkSize,
			maxBytes: maxBytes)
	}
	
	/// Writes a string to the device.
	/// - Parameters:
	///   - string: The string to write to the device.
	///   - terminator: The terminator to add to the end of `string`. By default, or if `nil`, `attributes.writeTerminator` is used.
	///   - encoding: The method to encode the string with. By default, or if `nil`, `attributes.encoding` is used.
	/// - Throws: If the device could not be written to.
	func write(
		_ string: String,
		appending terminator: String?? = .some(nil),
		encoding: String.Encoding? = nil
	) throws {
		try write(
			string,
			appending: terminator ?? attributes.writeTerminator,
			encoding: encoding ?? attributes.encoding)
	}
	
	/// Writes bytes to the device.
	/// - Parameters:
	///   - bytes: The data to write to the device.
	///   - terminator: The sequence of bytes to append to the end of `bytes`. By default, or if `nil`, `attributes.terminator` is used.
	/// - Throws: If the device could not be written to.
	func writeBytes(_ bytes: Data, appending terminator: Data?? = .some(nil)) throws {
		guard let terminator = terminator ??
						attributes.writeTerminator.data(using: attributes.encoding) else {
			throw CommunicatorError.couldNotEncode
		}
		
		try writeBytes(bytes, appending: terminator)
	}
}

/// An generic communicator error.
public enum CommunicatorError: Error {
	case couldNotEncode
}

/// Communication attributes for customizing communication to VISA complient instruments.
public struct CommunicatorAttributes {
	/// The string to terminate messages with when reading from an instrument.
	public var readTerminator = "\n"
	/// The string to terminate messages with when writing to an instrument.
	public var writeTerminator = "\n"
	/// The delay in seconds between reading to a device after writing to it.
	public var queryDelay: TimeInterval = 0.0
	/// The size in bytes to read data from the instrument at a time.
	public var chunkSize = 1024
	/// The string encoding to use when decoding from the instrument, or when encoding to write to the instrument.
	public var encoding: String.Encoding = .utf8
}

