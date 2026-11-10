import XCTest
@testable import CollectionImport

/// Generic CSV handling only. Column mapping for Poke Genie is written after seeing a real export.
final class CSVReaderTests: XCTestCase {
    func testCommaSeparated() throws {
        let t = try CSVReader.read("Name,CP,Note\nAlpha,1500,hi\nBeta,2500,\n")
        XCTAssertEqual(t.delimiter, ",")
        XCTAssertEqual(t.headers, ["Name", "CP", "Note"])
        XCTAssertEqual(t.rows, [["Alpha", "1500", "hi"], ["Beta", "2500", ""]])
    }

    func testSemicolonSeparatedWithDecimalComma() throws {
        let t = try CSVReader.read("Name;IV %;Level\r\nAlpha;95,6;30,5\r\n")
        XCTAssertEqual(t.delimiter, ";")
        XCTAssertEqual(t.rows.first, ["Alpha", "95,6", "30,5"])
        XCTAssertEqual(CSVReader.number(t.rows.first?[1]), 95.6)
        XCTAssertEqual(CSVReader.number("30.5"), 30.5)
        XCTAssertEqual(CSVReader.number("88%"), 88)
        XCTAssertNil(CSVReader.number(""))
        XCTAssertNil(CSVReader.number("abc"))
    }

    func testTabSeparated() throws {
        XCTAssertEqual(try CSVReader.read("a\tb\n1\t2").delimiter, "\t")
    }

    func testQuotedFieldsWithDelimitersQuotesAndNewlines() throws {
        let csv = "Name,Note\n\"Mr. Mime, the second\",\"He said \"\"hi\"\"\nand left\"\n"
        let t = try CSVReader.read(csv)
        XCTAssertEqual(t.rows.count, 1)
        XCTAssertEqual(t.rows[0][0], "Mr. Mime, the second")
        XCTAssertEqual(t.rows[0][1], "He said \"hi\"\nand left")
    }

    func testDelimiterInsideQuotedHeaderIsIgnoredForDetection() throws {
        let t = try CSVReader.read("\"a;b\",c,d\n1,2,3")
        XCTAssertEqual(t.delimiter, ",")
        XCTAssertEqual(t.headers, ["a;b", "c", "d"])
    }

    func testByteOrderMarkAndBlankLines() throws {
        let t = try CSVReader.read("\u{FEFF}Name,CP\n\nAlpha,10\n\n")
        XCTAssertEqual(t.headers.first, "Name")
        XCTAssertEqual(t.rows, [["Alpha", "10"]])
    }

    func testNoTrailingNewline() throws {
        XCTAssertEqual(try CSVReader.read("a,b\n1,2").rows, [["1", "2"]])
    }

    func testEmptyFileThrows() {
        XCTAssertThrowsError(try CSVReader.read("  \n "))
        XCTAssertThrowsError(try CSVReader.read(Data()))
    }

    func testColumnLookupIgnoresCaseAndPunctuation() throws {
        let t = try CSVReader.read("Pokemon Number,Atk IV,Fast Move\n25,15,Thunder Shock")
        XCTAssertEqual(t.column("atk iv"), 1)
        XCTAssertEqual(t.column("FASTMOVE"), 2)
        XCTAssertNil(t.column("Nope"))
        XCTAssertEqual(t.value(t.rows[0], t.column("Fast Move")), "Thunder Shock")
        XCTAssertNil(t.value(t.rows[0], 9))
    }

    func testUTF16DataIsDecoded() throws {
        let data = try XCTUnwrap("Name,CP\nÉvoli,10".data(using: .utf16))
        XCTAssertEqual(try CSVReader.read(data).rows.first?.first, "Évoli")
    }
}
