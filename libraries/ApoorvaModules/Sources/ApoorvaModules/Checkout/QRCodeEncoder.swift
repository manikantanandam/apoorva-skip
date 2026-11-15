//
//  QRCodeEncoder.swift
//  ApoorvaModules
//

import SwiftUI

/// A square grid of QR modules; `true` is dark.
struct QRMatrix {
    let size: Int
    private let modules: [Bool]

    init(size: Int, modules: [Bool]) {
        self.size = size
        self.modules = modules
    }

    func isDark(_ x: Int, _ y: Int) -> Bool { modules[y * size + x] }
}

/// Pure-Swift QR encoder (byte mode, error correction M, versions 1–40, up to 2,331 bytes), used where CoreImage
/// isn't available (Android). Follows ISO/IEC 18004; block layout is derived from the per-version tables below.
enum QREncoder {
    /// Block layout for one version at level M: `shortBlocks` blocks of `shortData` data codewords, the rest one longer.
    private struct Spec {
        let ecPerBlock: Int
        let blockCount: Int
        let shortBlocks: Int
        let shortData: Int
        let dataCodewords: Int

        var longestBlock: Int { shortBlocks < blockCount ? shortData + 1 : shortData }
    }

    /// Error correction codewords per block, indexed by version − 1 (level M).
    private static let ecCodewordsPerBlock: [Int] = [
        10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26,
        26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28
    ]

    /// Number of error correction blocks, indexed by version − 1 (level M).
    private static let blockCounts: [Int] = [
        1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16,
        17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49
    ]

    /// Data modules available for codewords once finder, timing, alignment, format and version patterns are removed.
    private static func rawDataModules(_ version: Int) -> Int {
        let size = version * 4 + 17
        var result = size * size
        result -= 8 * 8 * 3          // three finder patterns with separators
        result -= 15 * 2 + 1         // format bits and the dark module
        result -= (size - 16) * 2    // timing patterns
        if version >= 2 {
            let aligns = version / 7 + 2
            result -= (aligns - 1) * (aligns - 1) * 25
            result -= (aligns - 2) * 2 * 20
            if version >= 7 { result -= 6 * 3 * 2 }
        }
        return result
    }

    private static func layout(for version: Int) -> Spec {
        let raw = rawDataModules(version) / 8
        let ec = ecCodewordsPerBlock[version - 1]
        let blocks = blockCounts[version - 1]
        return Spec(ecPerBlock: ec, blockCount: blocks, shortBlocks: blocks - raw % blocks,
                    shortData: raw / blocks - ec, dataCodewords: raw - ec * blocks)
    }

    private static func alignmentPositions(_ version: Int) -> [Int] {
        guard version > 1 else { return [] }
        let size = version * 4 + 17
        let aligns = version / 7 + 2
        let step = version == 32 ? 26 : (version * 4 + aligns * 2 + 1) / (aligns * 2 - 2) * 2
        var result = [6]
        var position = size - 7
        while result.count < aligns {
            result.insert(position, at: 1)
            position -= step
        }
        return result
    }

    static func encode(_ text: String) -> QRMatrix? {
        let bytes = Array(text.utf8)
        var versionFound: Int?
        for candidate in 1...40 {
            let countBits = candidate < 10 ? 8 : 16
            if (layout(for: candidate).dataCodewords * 8 - 4 - countBits) / 8 >= bytes.count {
                versionFound = candidate
                break
            }
        }
        guard let version = versionFound else { return nil }
        let spec = layout(for: version)

        let codewords = interleave(dataCodewords(bytes, version: version, spec: spec), spec: spec)
        var builder = Builder(version: version)
        builder.drawFunctionPatterns()
        builder.drawCodewords(codewords)

        var bestMask = 0
        var bestPenalty = Int.max
        for mask in 0..<8 {
            builder.applyMask(mask)
            builder.drawFormatBits(mask)
            let penalty = builder.penalty()
            if penalty < bestPenalty {
                bestPenalty = penalty
                bestMask = mask
            }
            builder.applyMask(mask)
        }
        builder.applyMask(bestMask)
        builder.drawFormatBits(bestMask)
        return builder.matrix()
    }

    // MARK: - Data

    private static func dataCodewords(_ bytes: [UInt8], version: Int, spec: Spec) -> [UInt8] {
        var bits: [Bool] = []
        func append(_ value: Int, _ count: Int) {
            for i in stride(from: count - 1, through: 0, by: -1) { bits.append((value >> i) & 1 == 1) }
        }
        append(0b0100, 4)
        append(bytes.count, version < 10 ? 8 : 16)
        for byte in bytes { append(Int(byte), 8) }
        let capacity = spec.dataCodewords * 8
        append(0, min(4, capacity - bits.count))
        while bits.count % 8 != 0 { bits.append(false) }
        var pad = 0xEC
        while bits.count < capacity {
            append(pad, 8)
            pad = pad == 0xEC ? 0x11 : 0xEC
        }
        var result: [UInt8] = []
        for i in stride(from: 0, to: bits.count, by: 8) {
            var value = 0
            for j in 0..<8 { value = (value << 1) | (bits[i + j] ? 1 : 0) }
            result.append(UInt8(value))
        }
        return result
    }

    private static func interleave(_ data: [UInt8], spec: Spec) -> [UInt8] {
        let divisor = reedSolomonDivisor(spec.ecPerBlock)
        var dataBlocks: [[UInt8]] = []
        var ecBlocks: [[UInt8]] = []
        var offset = 0
        for index in 0..<spec.blockCount {
            let length = index < spec.shortBlocks ? spec.shortData : spec.shortData + 1
            let block = Array(data[offset..<(offset + length)])
            offset += length
            dataBlocks.append(block)
            ecBlocks.append(reedSolomonRemainder(block, divisor))
        }
        var result: [UInt8] = []
        for i in 0..<spec.longestBlock {
            for block in dataBlocks where i < block.count { result.append(block[i]) }
        }
        for i in 0..<spec.ecPerBlock {
            for block in ecBlocks { result.append(block[i]) }
        }
        return result
    }

    // MARK: - Reed–Solomon over GF(256), polynomial 0x11D

    private static func multiply(_ x: Int, _ y: Int) -> Int {
        var z = 0
        for i in stride(from: 7, through: 0, by: -1) {
            z = (z << 1) ^ ((z >> 7) * 0x11D)
            z ^= ((y >> i) & 1) * x
        }
        return z
    }

    private static func reedSolomonDivisor(_ degree: Int) -> [Int] {
        var result = [Int](repeating: 0, count: degree)
        result[degree - 1] = 1
        var root = 1
        for _ in 0..<degree {
            for j in 0..<degree {
                result[j] = multiply(result[j], root)
                if j + 1 < degree { result[j] ^= result[j + 1] }
            }
            root = multiply(root, 0x02)
        }
        return result
    }

    private static func reedSolomonRemainder(_ data: [UInt8], _ divisor: [Int]) -> [UInt8] {
        var result = [Int](repeating: 0, count: divisor.count)
        for byte in data {
            let factor = Int(byte) ^ result.removeFirst()
            result.append(0)
            for i in 0..<result.count { result[i] ^= multiply(divisor[i], factor) }
        }
        return result.map { UInt8($0) }
    }

    // MARK: - Matrix

    private struct Builder {
        let version: Int
        let size: Int
        var modules: [[Bool]]
        var isFunction: [[Bool]]

        init(version: Int) {
            self.version = version
            size = version * 4 + 17
            modules = [[Bool]](repeating: [Bool](repeating: false, count: size), count: size)
            isFunction = modules
        }

        mutating func setFunction(_ x: Int, _ y: Int, _ dark: Bool) {
            modules[y][x] = dark
            isFunction[y][x] = true
        }

        mutating func drawFunctionPatterns() {
            for i in 0..<size {
                setFunction(6, i, i % 2 == 0)
                setFunction(i, 6, i % 2 == 0)
            }
            drawFinder(3, 3)
            drawFinder(size - 4, 3)
            drawFinder(3, size - 4)
            let positions = QREncoder.alignmentPositions(version)
            for i in 0..<positions.count {
                for j in 0..<positions.count {
                    let corner = (i == 0 && j == 0) || (i == 0 && j == positions.count - 1) || (i == positions.count - 1 && j == 0)
                    if !corner { drawAlignment(positions[i], positions[j]) }
                }
            }
            drawFormatBits(0)
            drawVersion()
        }

        private mutating func drawFinder(_ cx: Int, _ cy: Int) {
            for dy in -4...4 {
                for dx in -4...4 {
                    let x = cx + dx
                    let y = cy + dy
                    guard x >= 0, x < size, y >= 0, y < size else { continue }
                    let distance = max(abs(dx), abs(dy))
                    setFunction(x, y, distance != 2 && distance != 4)
                }
            }
        }

        private mutating func drawAlignment(_ cx: Int, _ cy: Int) {
            for dy in -2...2 {
                for dx in -2...2 {
                    setFunction(cx + dx, cy + dy, max(abs(dx), abs(dy)) != 1)
                }
            }
        }

        mutating func drawFormatBits(_ mask: Int) {
            let data = mask  // error correction level M is 0b00
            var remainder = data
            for _ in 0..<10 { remainder = (remainder << 1) ^ ((remainder >> 9) * 0x537) }
            let bits = ((data << 10) | remainder) ^ 0x5412
            func bit(_ i: Int) -> Bool { (bits >> i) & 1 == 1 }
            for i in 0...5 { setFunction(8, i, bit(i)) }
            setFunction(8, 7, bit(6))
            setFunction(8, 8, bit(7))
            setFunction(7, 8, bit(8))
            for i in 9..<15 { setFunction(14 - i, 8, bit(i)) }
            for i in 0..<8 { setFunction(size - 1 - i, 8, bit(i)) }
            for i in 8..<15 { setFunction(8, size - 15 + i, bit(i)) }
            setFunction(8, size - 8, true)
        }

        private mutating func drawVersion() {
            guard version >= 7 else { return }
            var remainder = version
            for _ in 0..<12 { remainder = (remainder << 1) ^ ((remainder >> 11) * 0x1F25) }
            let bits = (version << 12) | remainder
            for i in 0..<18 {
                let dark = (bits >> i) & 1 == 1
                let a = size - 11 + i % 3
                let b = i / 3
                setFunction(a, b, dark)
                setFunction(b, a, dark)
            }
        }

        mutating func drawCodewords(_ data: [UInt8]) {
            var bitIndex = 0
            var right = size - 1
            while right >= 1 {
                if right == 6 { right = 5 }
                for vertical in 0..<size {
                    for j in 0..<2 {
                        let x = right - j
                        let upward = ((right + 1) & 2) == 0
                        let y = upward ? size - 1 - vertical : vertical
                        if !isFunction[y][x] && bitIndex < data.count * 8 {
                            modules[y][x] = (Int(data[bitIndex >> 3]) >> (7 - (bitIndex & 7))) & 1 == 1
                            bitIndex += 1
                        }
                    }
                }
                right -= 2
            }
        }

        mutating func applyMask(_ mask: Int) {
            for y in 0..<size {
                for x in 0..<size where !isFunction[y][x] {
                    let invert: Bool
                    switch mask {
                    case 0: invert = (x + y) % 2 == 0
                    case 1: invert = y % 2 == 0
                    case 2: invert = x % 3 == 0
                    case 3: invert = (x + y) % 3 == 0
                    case 4: invert = (x / 3 + y / 2) % 2 == 0
                    case 5: invert = x * y % 2 + x * y % 3 == 0
                    case 6: invert = (x * y % 2 + x * y % 3) % 2 == 0
                    default: invert = ((x + y) % 2 + x * y % 3) % 2 == 0
                    }
                    if invert { modules[y][x] = !modules[y][x] }
                }
            }
        }

        /// Run-length, 2×2 block and dark-balance penalties (the finder-like-pattern rule is omitted; any mask is valid).
        func penalty() -> Int {
            var total = 0
            for transpose in [false, true] {
                for a in 0..<size {
                    var run = 1
                    for b in 1..<size {
                        let current = transpose ? modules[b][a] : modules[a][b]
                        let previous = transpose ? modules[b - 1][a] : modules[a][b - 1]
                        if current == previous {
                            run += 1
                            if run == 5 { total += 3 } else if run > 5 { total += 1 }
                        } else {
                            run = 1
                        }
                    }
                }
            }
            for y in 0..<(size - 1) {
                for x in 0..<(size - 1) {
                    let color = modules[y][x]
                    if color == modules[y][x + 1] && color == modules[y + 1][x] && color == modules[y + 1][x + 1] { total += 3 }
                }
            }
            var dark = 0
            for row in modules { for module in row where module { dark += 1 } }
            let cells = size * size
            let deviation = (abs(dark * 20 - cells * 10) + cells - 1) / cells - 1
            return total + deviation * 10
        }

        func matrix() -> QRMatrix {
            var flat: [Bool] = []
            for row in modules { flat.append(contentsOf: row) }
            return QRMatrix(size: size, modules: flat)
        }
    }
}

/// Dark modules drawn as one path, surrounded by the 4-module quiet zone the QR spec requires.
struct QRShape: Shape {
    let matrix: QRMatrix

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let quietZone = 4
        let cell = rect.width / CGFloat(matrix.size + quietZone * 2)
        for y in 0..<matrix.size {
            for x in 0..<matrix.size where matrix.isDark(x, y) {
                path.addRect(CGRect(x: rect.minX + CGFloat(x + quietZone) * cell,
                                    y: rect.minY + CGFloat(y + quietZone) * cell,
                                    width: cell, height: cell))
            }
        }
        return path
    }
}
