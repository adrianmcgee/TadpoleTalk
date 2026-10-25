import UIKit
import SwiftData

/// Turns practice history into two things a parent can hand to their speech pathologist at
/// the weekly appointment: a tidy one-page PDF summary and a raw CSV of every trial. No
/// data leaves the device unless the parent chooses to share it.
struct ReportExporter {
    let vm = ProgressViewModel()

    /// CSV with one row per trial: the SLP can pivot it however they like.
    func makeCSV(for child: Child) -> String {
        var rows = ["date,time,word,rating,prompting"]
        let dateFmt = DateFormatter(); dateFmt.dateFormat = "yyyy-MM-dd"
        let timeFmt = DateFormatter(); timeFmt.dateFormat = "HH:mm"
        let trials = child.sessions
            .flatMap { $0.trials }
            .sorted { $0.timestamp < $1.timestamp }
        for trial in trials {
            let word = trial.targetText.replacingOccurrences(of: ",", with: " ")
            rows.append("\(dateFmt.string(from: trial.timestamp)),\(timeFmt.string(from: trial.timestamp)),"
                        + "\(word),\(trial.rating.rawValue),\(trial.prompt?.rawValue ?? "")")
        }
        return rows.joined(separator: "\n")
    }

    /// Write the CSV to a temporary file and return its URL (for the share sheet).
    func writeCSV(for child: Child) -> URL? {
        let csv = makeCSV(for: child)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TadpoleTalk-\(safeName(child)).csv")
        do { try csv.write(to: url, atomically: true, encoding: .utf8); return url }
        catch { return nil }
    }

    /// A printable one-page summary: headline numbers and a per-word table.
    func writePDF(for child: Child) -> URL? {
        let pageRect = CGRect(x: 0, y: 0, width: 595, height: 842) // A4 @ 72dpi
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TadpoleTalk-\(safeName(child)).pdf")

        let targets = vm.perTarget(child)
        let dateFmt = DateFormatter(); dateFmt.dateStyle = .medium

        do {
            try renderer.writePDF(to: url) { ctx in
                ctx.beginPage()
                var y: CGFloat = 48
                let left: CGFloat = 48

                draw("Tadpole Talk — practice summary", at: CGPoint(x: left, y: y), font: .boldSystemFont(ofSize: 22))
                y += 30
                draw("\(child.name) · generated \(dateFmt.string(from: Date()))",
                     at: CGPoint(x: left, y: y), font: .systemFont(ofSize: 12), color: .darkGray)
                y += 36

                let summary = "Sessions: \(vm.totalSessions(child))    "
                    + "Successful reps: \(vm.totalSuccesses(child))    "
                    + "Total tries: \(vm.totalTrials(child))    "
                    + "Words coming along: \(vm.masteredCount(child))"
                draw(summary, at: CGPoint(x: left, y: y), font: .systemFont(ofSize: 13))
                y += 36

                draw("Word", at: CGPoint(x: left, y: y), font: .boldSystemFont(ofSize: 13))
                draw("Great reps", at: CGPoint(x: 200, y: y), font: .boldSystemFont(ofSize: 13))
                draw("Tries", at: CGPoint(x: 290, y: y), font: .boldSystemFont(ofSize: 13))
                draw("Success", at: CGPoint(x: 350, y: y), font: .boldSystemFont(ofSize: 13))
                draw("Best prompting", at: CGPoint(x: 430, y: y), font: .boldSystemFont(ofSize: 13))
                y += 22

                for target in targets {
                    if y > pageRect.height - 60 { ctx.beginPage(); y = 48 }
                    let word = target.movement.map { "\(target.word) (\($0.title))" } ?? target.word
                    draw(word, at: CGPoint(x: left, y: y), font: .systemFont(ofSize: 12))
                    draw("\(target.successes)", at: CGPoint(x: 200, y: y), font: .systemFont(ofSize: 12))
                    draw("\(target.total)", at: CGPoint(x: 290, y: y), font: .systemFont(ofSize: 12))
                    draw("\(Int(target.rate * 100))%", at: CGPoint(x: 350, y: y), font: .systemFont(ofSize: 12))
                    draw(target.leastPromptForSuccess?.summary ?? "–", at: CGPoint(x: 430, y: y),
                         font: .systemFont(ofSize: 12))
                    y += 20
                }

                if targets.isEmpty {
                    draw("No practice logged yet.", at: CGPoint(x: left, y: y),
                         font: .systemFont(ofSize: 12), color: .darkGray)
                }
            }
            return url
        } catch {
            return nil
        }
    }

    private func safeName(_ child: Child) -> String {
        let base = child.name.isEmpty ? "child" : child.name
        return base.components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
    }

    private func draw(_ text: String, at point: CGPoint, font: UIFont, color: UIColor = .black) {
        (text as NSString).draw(at: point, withAttributes: [.font: font, .foregroundColor: color])
    }
}
