//
//  ExportService.swift
//  iExpense
//
//  CSV + OFX export for accountant-ready reports (Pro).
//

import Foundation
import UIKit

enum ExportService {
    static func csvURL(expenses: [Expense], currencyCode: String) -> URL? {
        var lines = ["Date,Title,Type,Category,Amount,Notes"]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        for expense in expenses.sorted(by: { $0.date > $1.date }) {
            let date = dateFormatter.string(from: expense.date)
            let title = csvEscape(expense.title)
            let type = expense.type.rawValue
            let category = csvEscape(expense.category.displayName)
            let amount = String(format: "%.2f", expense.price)
            let notes = csvEscape(expense.notes ?? "")
            lines.append("\(date),\(title),\(type),\(category),\(amount),\(notes)")
        }

        return writeTemp(filename: "Expense_export.csv", contents: lines.joined(separator: "\n"))
    }

    static func ofxURL(expenses: [Expense], currencyCode: String) -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMddHHmmss"
        let now = dateFormatter.string(from: Date())

        var body = """
        OFXHEADER:100
        DATA:OFXSGML
        VERSION:102
        SECURITY:NONE
        ENCODING:USASCII
        CHARSET:1252
        COMPRESSION:NONE
        OLDFILEUID:NONE
        NEWFILEUID:NONE

        <OFX>
        <SIGNONMSGSRSV1>
        <SONRS>
        <STATUS><CODE>0<SEVERITY>INFO</STATUS>
        <DTSERVER>\(now)
        <LANGUAGE>ENG
        </SONRS>
        </SIGNONMSGSRSV1>
        <BANKMSGSRSV1>
        <STMTTRNRS>
        <TRNUID>1
        <STATUS><CODE>0<SEVERITY>INFO</STATUS>
        <STMTRS>
        <CURDEF>\(currencyCode)
        <BANKACCTFROM>
        <BANKID>INPENSO
        <ACCTID>LEDGER
        <ACCTTYPE>CHECKING
        </BANKACCTFROM>
        <BANKTRANLIST>
        """

        for expense in expenses.sorted(by: { $0.date < $1.date }) {
            let posted = dateFormatter.string(from: expense.date)
            let amount: String
            if expense.type == .income {
                amount = String(format: "%.2f", expense.price)
            } else {
                amount = String(format: "%.2f", -expense.price)
            }
            let fitid = expense.id.uuidString.replacingOccurrences(of: "-", with: "")
            let name = ofxEscape(expense.title)
            let memo = ofxEscape(expense.notes ?? expense.category.displayName)
            body += """

            <STMTTRN>
            <TRNTYPE>\(expense.type == .income ? "CREDIT" : "DEBIT")
            <DTPOSTED>\(posted)
            <TRNAMT>\(amount)
            <FITID>\(fitid)
            <NAME>\(name)
            <MEMO>\(memo)
            </STMTTRN>
            """
        }

        body += """

        </BANKTRANLIST>
        </STMTRS>
        </STMTTRNRS>
        </BANKMSGSRSV1>
        </OFX>
        """

        return writeTemp(filename: "Expense_export.ofx", contents: body)
    }

    static func pdfURL(expenses: [Expense], currencyCode: String) -> URL? {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 36
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Expense_report.pdf")

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        do {
            try renderer.writePDF(to: url) { context in
                var y: CGFloat = margin
                func newPageIfNeeded(_ needed: CGFloat) {
                    if y + needed > pageHeight - margin {
                        context.beginPage()
                        y = margin
                    }
                }

                context.beginPage()
                let title = "\(AppBrand.name) export" as NSString
                title.draw(at: CGPoint(x: margin, y: y), withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 18),
                    .foregroundColor: UIColor.label
                ])
                y += 28
                let subtitle = "Currency: \(currencyCode) · \(expenses.count) transactions" as NSString
                subtitle.draw(at: CGPoint(x: margin, y: y), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 12),
                    .foregroundColor: UIColor.secondaryLabel
                ])
                y += 24

                let dateFormatter = DateFormatter()
                dateFormatter.dateStyle = .medium

                for expense in expenses.sorted(by: { $0.date > $1.date }) {
                    newPageIfNeeded(36)
                    let line = "\(dateFormatter.string(from: expense.date))  \(expense.title)  \(expense.type.rawValue)  \(expense.homeAmount.formatted(.currency(code: currencyCode)))"
                    (line as NSString).draw(
                        in: CGRect(x: margin, y: y, width: pageWidth - margin * 2, height: 32),
                        withAttributes: [
                            .font: UIFont.systemFont(ofSize: 11),
                            .foregroundColor: UIColor.label
                        ]
                    )
                    y += 22
                }
            }
            return url
        } catch {
            return nil
        }
    }

    private static func csvEscape(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        if escaped.contains(",") || escaped.contains("\"") || escaped.contains("\n") {
            return "\"\(escaped)\""
        }
        return escaped
    }

    private static func ofxEscape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func writeTemp(filename: String, contents: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }
}
