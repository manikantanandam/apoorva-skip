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

/// Pure-Swift QR encoder (byte mode, error correction M, versions 1–10, up to 213 bytes), used where CoreImage
/// isn't available (Android). Follows ISO/IEC 18004; enough for `upi://pay` links.
enum QREncoder {
    private struct Spec {
        let ecPerBlock: Int
        let group1Blocks: Int
        let group1Data: Int
        let group2Blocks: Int
        let group2Data: Int

        var blockCount: Int { group1Blocks + group2Blocks }
        var dataCodewords: Int { group1Blocks * group1Data + group2Blocks * group2Data }
    }

    /// Indexed by version − 1, error correction level M.
    private static let specs: [Spec] = [
        Spec(ecPerBlock: 10, group1Blocks: 1, group1Data: 16, group2Blocks: 0, group2Data: 0),
        Spec(ecPerBlock: 16, group1Blocks: 1, group1Data: 28, group2Blocks: 0, group2Data: 0),
        Spec(ecPerBlock: 26, group1Blocks: 1, group1Data: 44, group2Blocks: 0, group2Data: 0),
        Spec(ecPerBlock: 18, group1Blocks: 2, group1Data: 32, group2Blocks: 0, group2Data: 0),
        Spec(ecPerBlock: 24, group1Blocks: 2, group1Data: 43, group2Blocks: 0, group2Data: 0),
        Spec(ecPerBlock: 16, group1Blocks: 4, group1Data: 27, group2Blocks: 0, group2Data: 0),
        Spec(ecPerBlock: 18, group1Blocks: 4, group1Data: 31, group2Blocks: 0, group2Data: 0),
        Spec(ecPerBlock: 22, group1Blocks: 2, group1Data: 38, group2Blocks: 2, group2Data: 39),
        Spec(ecPerBlock: 22, group1Blocks: 3, group1Data: 36, group2Blocks: 2, group2Data: 37),
        Spec(ecPerBlock: 26, group1Blocks: 4, group1Data: 43, group2Blocks: 1, group2Data: 44)
    ]

    private static let alignmentPositions: [[Int]] = [
        [], [6, 18], [6, 22], [6, 26], [6, 30], [6, 34], [6, 22, 38], [6, 24, 42], [6, 26, 46], [6, 28, 50]
    ]

    static func encode(_ text: String) -> QRMatrix? {
        let bytes = Array(text.utf8)
        var versionFound: Int?
        for candidate in 1...10 {
            let countBits = candidate < 10 ? 8 : 16
            if (specs[candidate - 1].dataCodewords * 8 - 4 - countBits) / 8 >= bytes.count {
                versionFound = candidate
                break
            }
        }
        guard let version = versionFound else { return nil }
        let spec = specs[version - 1]

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
            let length = index < spec.group1Blocks ? spec.group1Data : spec.group2Data
            let block = Array(data[offset..<(offset + length)])
            offset += length
            dataBlocks.append(block)
            ecBlocks.append(reedSolomonRemainder(block, divisor))
        }
        var result: [UInt8] = []
        for i in 0..<max(spec.group1Data, spec.group2Data) {
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
            let positions = QREncoder.alignmentPositions[version - 1]
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
