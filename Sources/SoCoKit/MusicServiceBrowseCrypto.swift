import Foundation

// MARK: - Protocol crypto used by ThirdPartyMediaServersX

/// Small dependency-free implementations of the protocol primitives required to
/// decode Sonos's encrypted `ThirdPartyMediaServersX` account envelope.
///
/// MD5 and AES-CBC are used here because Sonos defines them on the wire. They are
/// not exposed as general-purpose cryptographic APIs and should not be reused for
/// new application protocols.
internal enum MusicServiceBrowseCrypto {
    static func md5(_ data: Data) -> Data {
        var message = [UInt8](data)
        let bitLength = UInt64(message.count) * 8
        message.append(0x80)
        while message.count % 64 != 56 { message.append(0) }
        for shift in stride(from: 0, through: 56, by: 8) {
            message.append(UInt8(truncatingIfNeeded: bitLength >> UInt64(shift)))
        }

        var a0: UInt32 = 0x67452301
        var b0: UInt32 = 0xefcdab89
        var c0: UInt32 = 0x98badcfe
        var d0: UInt32 = 0x10325476

        let shifts: [UInt32] = [
            7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22,
            5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
            4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23,
            6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
        ]
        let constants: [UInt32] = (0..<64).map { index in
            UInt32(abs(sin(Double(index + 1))) * 4_294_967_296.0)
        }

        for offset in stride(from: 0, to: message.count, by: 64) {
            var words = [UInt32](repeating: 0, count: 16)
            for index in 0..<16 {
                let start = offset + index * 4
                words[index] = UInt32(message[start])
                    | UInt32(message[start + 1]) << 8
                    | UInt32(message[start + 2]) << 16
                    | UInt32(message[start + 3]) << 24
            }

            var a = a0
            var b = b0
            var c = c0
            var d = d0

            for index in 0..<64 {
                let f: UInt32
                let g: Int
                switch index {
                case 0..<16:
                    f = (b & c) | ((~b) & d)
                    g = index
                case 16..<32:
                    f = (d & b) | ((~d) & c)
                    g = (5 * index + 1) % 16
                case 32..<48:
                    f = b ^ c ^ d
                    g = (3 * index + 5) % 16
                default:
                    f = c ^ (b | (~d))
                    g = (7 * index) % 16
                }

                let sum = a &+ f &+ constants[index] &+ words[g]
                let rotated = (sum << shifts[index]) | (sum >> (32 - shifts[index]))
                let nextD = c
                c = b
                b = b &+ rotated
                a = d
                d = nextD
            }

            a0 = a0 &+ a
            b0 = b0 &+ b
            c0 = c0 &+ c
            d0 = d0 &+ d
        }

        var digest = Data()
        for value in [a0, b0, c0, d0] {
            digest.append(UInt8(truncatingIfNeeded: value))
            digest.append(UInt8(truncatingIfNeeded: value >> 8))
            digest.append(UInt8(truncatingIfNeeded: value >> 16))
            digest.append(UInt8(truncatingIfNeeded: value >> 24))
        }
        return digest
    }

    static func sha1(_ data: Data) -> Data {
        var message = [UInt8](data)
        let bitLength = UInt64(message.count) * 8
        message.append(0x80)
        while message.count % 64 != 56 { message.append(0) }
        for shift in stride(from: 56, through: 0, by: -8) {
            message.append(UInt8(truncatingIfNeeded: bitLength >> UInt64(shift)))
        }

        var h0: UInt32 = 0x67452301
        var h1: UInt32 = 0xefcdab89
        var h2: UInt32 = 0x98badcfe
        var h3: UInt32 = 0x10325476
        var h4: UInt32 = 0xc3d2e1f0

        for offset in stride(from: 0, to: message.count, by: 64) {
            var words = [UInt32](repeating: 0, count: 80)
            for index in 0..<16 {
                let start = offset + index * 4
                words[index] = UInt32(message[start]) << 24
                    | UInt32(message[start + 1]) << 16
                    | UInt32(message[start + 2]) << 8
                    | UInt32(message[start + 3])
            }
            for index in 16..<80 {
                words[index] = rotateLeft(
                    words[index - 3] ^ words[index - 8]
                        ^ words[index - 14] ^ words[index - 16],
                    by: 1
                )
            }

            var a = h0
            var b = h1
            var c = h2
            var d = h3
            var e = h4

            for index in 0..<80 {
                let f: UInt32
                let k: UInt32
                switch index {
                case 0..<20:
                    f = (b & c) | ((~b) & d)
                    k = 0x5a827999
                case 20..<40:
                    f = b ^ c ^ d
                    k = 0x6ed9eba1
                case 40..<60:
                    f = (b & c) | (b & d) | (c & d)
                    k = 0x8f1bbcdc
                default:
                    f = b ^ c ^ d
                    k = 0xca62c1d6
                }
                let temporary = rotateLeft(a, by: 5) &+ f &+ e &+ k &+ words[index]
                e = d
                d = c
                c = rotateLeft(b, by: 30)
                b = a
                a = temporary
            }

            h0 = h0 &+ a
            h1 = h1 &+ b
            h2 = h2 &+ c
            h3 = h3 &+ d
            h4 = h4 &+ e
        }

        var digest = Data()
        for value in [h0, h1, h2, h3, h4] {
            digest.append(UInt8(truncatingIfNeeded: value >> 24))
            digest.append(UInt8(truncatingIfNeeded: value >> 16))
            digest.append(UInt8(truncatingIfNeeded: value >> 8))
            digest.append(UInt8(truncatingIfNeeded: value))
        }
        return digest
    }

    static func aes128CBCDecrypt(ciphertext: Data, key: Data, iv: Data) throws -> Data {
        guard key.count == 16, iv.count == 16, !ciphertext.isEmpty,
              ciphertext.count.isMultiple(of: 16)
        else {
            throw SoCoError.musicService("Invalid AES-128-CBC input dimensions")
        }

        let roundKeys = expandAES128Key([UInt8](key))
        let encrypted = [UInt8](ciphertext)
        var previous = [UInt8](iv)
        var plaintext = [UInt8]()
        plaintext.reserveCapacity(encrypted.count)

        for offset in stride(from: 0, to: encrypted.count, by: 16) {
            let block = Array(encrypted[offset..<(offset + 16)])
            let decrypted = decryptAESBlock(block, roundKeys: roundKeys)
            plaintext.append(contentsOf: zip(decrypted, previous).map(^))
            previous = block
        }

        guard let paddingLength = plaintext.last.map(Int.init),
              (1...16).contains(paddingLength),
              plaintext.count >= paddingLength
        else {
            throw SoCoError.musicService("Invalid PKCS#7 padding in account payload")
        }
        let padding = plaintext.suffix(paddingLength)
        guard padding.allSatisfy({ Int($0) == paddingLength }) else {
            throw SoCoError.musicService("Invalid PKCS#7 padding in account payload")
        }
        plaintext.removeLast(paddingLength)
        return Data(plaintext)
    }

    private static func rotateLeft(_ value: UInt32, by count: UInt32) -> UInt32 {
        (value << count) | (value >> (32 - count))
    }

    private static func expandAES128Key(_ key: [UInt8]) -> [UInt8] {
        var expanded = key
        expanded.reserveCapacity(176)
        var bytesGenerated = 16
        var rconIndex = 1
        var temporary = [UInt8](repeating: 0, count: 4)

        while bytesGenerated < 176 {
            for index in 0..<4 { temporary[index] = expanded[bytesGenerated - 4 + index] }
            if bytesGenerated.isMultiple(of: 16) {
                temporary = [temporary[1], temporary[2], temporary[3], temporary[0]]
                for index in 0..<4 { temporary[index] = aesSBox[Int(temporary[index])] }
                temporary[0] ^= aesRcon[rconIndex]
                rconIndex += 1
            }
            for index in 0..<4 {
                expanded.append(expanded[bytesGenerated - 16] ^ temporary[index])
                bytesGenerated += 1
            }
        }
        return expanded
    }

    private static func decryptAESBlock(_ block: [UInt8], roundKeys: [UInt8]) -> [UInt8] {
        var state = block
        addRoundKey(&state, roundKeys: roundKeys, round: 10)
        for round in stride(from: 9, through: 1, by: -1) {
            inverseShiftRows(&state)
            for index in state.indices { state[index] = aesInverseSBox[Int(state[index])] }
            addRoundKey(&state, roundKeys: roundKeys, round: round)
            inverseMixColumns(&state)
        }
        inverseShiftRows(&state)
        for index in state.indices { state[index] = aesInverseSBox[Int(state[index])] }
        addRoundKey(&state, roundKeys: roundKeys, round: 0)
        return state
    }

    private static func addRoundKey(_ state: inout [UInt8], roundKeys: [UInt8], round: Int) {
        let offset = round * 16
        for index in 0..<16 { state[index] ^= roundKeys[offset + index] }
    }

    private static func inverseShiftRows(_ state: inout [UInt8]) {
        let old = state
        state[1] = old[13]; state[5] = old[1]; state[9] = old[5]; state[13] = old[9]
        state[2] = old[10]; state[6] = old[14]; state[10] = old[2]; state[14] = old[6]
        state[3] = old[7]; state[7] = old[11]; state[11] = old[15]; state[15] = old[3]
    }

    private static func inverseMixColumns(_ state: inout [UInt8]) {
        for column in 0..<4 {
            let index = column * 4
            let a = Array(state[index..<(index + 4)])
            state[index] = multiply(a[0], 14) ^ multiply(a[1], 11)
                ^ multiply(a[2], 13) ^ multiply(a[3], 9)
            state[index + 1] = multiply(a[0], 9) ^ multiply(a[1], 14)
                ^ multiply(a[2], 11) ^ multiply(a[3], 13)
            state[index + 2] = multiply(a[0], 13) ^ multiply(a[1], 9)
                ^ multiply(a[2], 14) ^ multiply(a[3], 11)
            state[index + 3] = multiply(a[0], 11) ^ multiply(a[1], 13)
                ^ multiply(a[2], 9) ^ multiply(a[3], 14)
        }
    }

    private static func multiply(_ value: UInt8, _ factor: UInt8) -> UInt8 {
        var a = value
        var b = factor
        var product: UInt8 = 0
        while b != 0 {
            if b & 1 != 0 { product ^= a }
            let highBit = a & 0x80
            a <<= 1
            if highBit != 0 { a ^= 0x1b }
            b >>= 1
        }
        return product
    }

    private static let aesRcon: [UInt8] = [
        0x00, 0x01, 0x02, 0x04, 0x08, 0x10, 0x20, 0x40, 0x80, 0x1b, 0x36,
    ]

    private static let aesSBox: [UInt8] = [
        0x63,0x7c,0x77,0x7b,0xf2,0x6b,0x6f,0xc5,0x30,0x01,0x67,0x2b,0xfe,0xd7,0xab,0x76,
        0xca,0x82,0xc9,0x7d,0xfa,0x59,0x47,0xf0,0xad,0xd4,0xa2,0xaf,0x9c,0xa4,0x72,0xc0,
        0xb7,0xfd,0x93,0x26,0x36,0x3f,0xf7,0xcc,0x34,0xa5,0xe5,0xf1,0x71,0xd8,0x31,0x15,
        0x04,0xc7,0x23,0xc3,0x18,0x96,0x05,0x9a,0x07,0x12,0x80,0xe2,0xeb,0x27,0xb2,0x75,
        0x09,0x83,0x2c,0x1a,0x1b,0x6e,0x5a,0xa0,0x52,0x3b,0xd6,0xb3,0x29,0xe3,0x2f,0x84,
        0x53,0xd1,0x00,0xed,0x20,0xfc,0xb1,0x5b,0x6a,0xcb,0xbe,0x39,0x4a,0x4c,0x58,0xcf,
        0xd0,0xef,0xaa,0xfb,0x43,0x4d,0x33,0x85,0x45,0xf9,0x02,0x7f,0x50,0x3c,0x9f,0xa8,
        0x51,0xa3,0x40,0x8f,0x92,0x9d,0x38,0xf5,0xbc,0xb6,0xda,0x21,0x10,0xff,0xf3,0xd2,
        0xcd,0x0c,0x13,0xec,0x5f,0x97,0x44,0x17,0xc4,0xa7,0x7e,0x3d,0x64,0x5d,0x19,0x73,
        0x60,0x81,0x4f,0xdc,0x22,0x2a,0x90,0x88,0x46,0xee,0xb8,0x14,0xde,0x5e,0x0b,0xdb,
        0xe0,0x32,0x3a,0x0a,0x49,0x06,0x24,0x5c,0xc2,0xd3,0xac,0x62,0x91,0x95,0xe4,0x79,
        0xe7,0xc8,0x37,0x6d,0x8d,0xd5,0x4e,0xa9,0x6c,0x56,0xf4,0xea,0x65,0x7a,0xae,0x08,
        0xba,0x78,0x25,0x2e,0x1c,0xa6,0xb4,0xc6,0xe8,0xdd,0x74,0x1f,0x4b,0xbd,0x8b,0x8a,
        0x70,0x3e,0xb5,0x66,0x48,0x03,0xf6,0x0e,0x61,0x35,0x57,0xb9,0x86,0xc1,0x1d,0x9e,
        0xe1,0xf8,0x98,0x11,0x69,0xd9,0x8e,0x94,0x9b,0x1e,0x87,0xe9,0xce,0x55,0x28,0xdf,
        0x8c,0xa1,0x89,0x0d,0xbf,0xe6,0x42,0x68,0x41,0x99,0x2d,0x0f,0xb0,0x54,0xbb,0x16,
    ]

    private static let aesInverseSBox: [UInt8] = [
        0x52,0x09,0x6a,0xd5,0x30,0x36,0xa5,0x38,0xbf,0x40,0xa3,0x9e,0x81,0xf3,0xd7,0xfb,
        0x7c,0xe3,0x39,0x82,0x9b,0x2f,0xff,0x87,0x34,0x8e,0x43,0x44,0xc4,0xde,0xe9,0xcb,
        0x54,0x7b,0x94,0x32,0xa6,0xc2,0x23,0x3d,0xee,0x4c,0x95,0x0b,0x42,0xfa,0xc3,0x4e,
        0x08,0x2e,0xa1,0x66,0x28,0xd9,0x24,0xb2,0x76,0x5b,0xa2,0x49,0x6d,0x8b,0xd1,0x25,
        0x72,0xf8,0xf6,0x64,0x86,0x68,0x98,0x16,0xd4,0xa4,0x5c,0xcc,0x5d,0x65,0xb6,0x92,
        0x6c,0x70,0x48,0x50,0xfd,0xed,0xb9,0xda,0x5e,0x15,0x46,0x57,0xa7,0x8d,0x9d,0x84,
        0x90,0xd8,0xab,0x00,0x8c,0xbc,0xd3,0x0a,0xf7,0xe4,0x58,0x05,0xb8,0xb3,0x45,0x06,
        0xd0,0x2c,0x1e,0x8f,0xca,0x3f,0x0f,0x02,0xc1,0xaf,0xbd,0x03,0x01,0x13,0x8a,0x6b,
        0x3a,0x91,0x11,0x41,0x4f,0x67,0xdc,0xea,0x97,0xf2,0xcf,0xce,0xf0,0xb4,0xe6,0x73,
        0x96,0xac,0x74,0x22,0xe7,0xad,0x35,0x85,0xe2,0xf9,0x37,0xe8,0x1c,0x75,0xdf,0x6e,
        0x47,0xf1,0x1a,0x71,0x1d,0x29,0xc5,0x89,0x6f,0xb7,0x62,0x0e,0xaa,0x18,0xbe,0x1b,
        0xfc,0x56,0x3e,0x4b,0xc6,0xd2,0x79,0x20,0x9a,0xdb,0xc0,0xfe,0x78,0xcd,0x5a,0xf4,
        0x1f,0xdd,0xa8,0x33,0x88,0x07,0xc7,0x31,0xb1,0x12,0x10,0x59,0x27,0x80,0xec,0x5f,
        0x60,0x51,0x7f,0xa9,0x19,0xb5,0x4a,0x0d,0x2d,0xe5,0x7a,0x9f,0x93,0xc9,0x9c,0xef,
        0xa0,0xe0,0x3b,0x4d,0xae,0x2a,0xf5,0xb0,0xc8,0xeb,0xbb,0x3c,0x83,0x53,0x99,0x61,
        0x17,0x2b,0x04,0x7e,0xba,0x77,0xd6,0x26,0xe1,0x69,0x14,0x63,0x55,0x21,0x0c,0x7d,
    ]
}
