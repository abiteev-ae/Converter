import XCTest

final class ConverterUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }
    
    func test_CurrencyConversion_ResponseTimeLogging_ForEURandGBP() throws {
        let amountTextField = app.textFields[AccessibilityID.amountTextField]
        XCTAssertTrue(amountTextField.waitForExistence(timeout: 5), "Amount text field is missing")

        amountTextField.tap()
        amountTextField.typeText("100")

        let convertButton = app.buttons[AccessibilityID.convertButton]
        XCTAssertTrue(convertButton.exists, "Convert button is missing")

        let eurEntry = try measureConversionTime(
            currencyButton: app.segmentedControls.buttons["EUR"],
            convertButton: convertButton,
            expectedCurrencyCode: "EUR"
        )

        let gbpEntry = try measureConversionTime(
            currencyButton: app.segmentedControls.buttons["GBP"],
            convertButton: convertButton,
            expectedCurrencyCode: "GBP"
        )

        let fileURL = try saveLogAsJSON([eurEntry, gbpEntry])
        XCTContext.runActivity(named: "Response log JSON path") { activity in
            activity.add(XCTAttachment(string: fileURL.path))
        }
        try attachJSONLogFile(fileURL: fileURL)
    }

    private func measureConversionTime(
        currencyButton: XCUIElement,
        convertButton: XCUIElement,
        expectedCurrencyCode: String
    ) throws -> ConversionLogEntry {
        XCTAssertTrue(currencyButton.exists, "Currency segment button is missing: \(expectedCurrencyCode)")
        currencyButton.tap()

        let resultLabel = app.staticTexts[AccessibilityID.resultLabel]
        XCTAssertTrue(resultLabel.exists, "Result label is missing")
        let previousValue = resultLabel.label

        let startedAt = Date()
        convertButton.tap()

        let resultPredicate = NSPredicate { _, _ in
            let updatedValue = resultLabel.label
            return updatedValue != previousValue && updatedValue.contains("Result:") && updatedValue.contains(expectedCurrencyCode)
        }

        let expectation = XCTNSPredicateExpectation(predicate: resultPredicate, object: nil)
        let waitResult = XCTWaiter.wait(for: [expectation], timeout: 10)
        XCTAssertEqual(waitResult, .completed, "Conversion did not finish for \(expectedCurrencyCode)")

        let durationMilliseconds = Int(Date().timeIntervalSince(startedAt) * 1000)
        return ConversionLogEntry(
            currency: expectedCurrencyCode,
            inputUSD: "100",
            responseTimeMs: durationMilliseconds,
            resultText: resultLabel.label,
            timestampISO8601: ISO8601DateFormatter().string(from: Date())
        )
    }

    private func saveLogAsJSON(_ entries: [ConversionLogEntry]) throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entries)

        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("conversion_response_log.json")
        try data.write(to: outputURL, options: .atomic)
        print("JSON log saved at: \(outputURL.path)")

        return outputURL
    }

    private func attachJSONLogFile(fileURL: URL) throws {
        let jsonData = try Data(contentsOf: fileURL)
        let attachment = XCTAttachment(data: jsonData, uniformTypeIdentifier: "public.json")
        attachment.name = "conversion_response_log.json"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private struct ConversionLogEntry: Codable {
    let currency: String
    let inputUSD: String
    let responseTimeMs: Int
    let resultText: String
    let timestampISO8601: String
}
