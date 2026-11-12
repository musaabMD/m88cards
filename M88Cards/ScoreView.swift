import SwiftUI

struct ScoreView: View {
    @Environment(Store.self) private var store
    let session: QuizSession
    var onRetry: ([Card]) -> Void
    var onDone: () -> Void

    private var record: SessionRecord? { store.lastSession(scopeID: session.scope.id) }

    var body: some View {
        let right = session.rightSoFar, total = session.firstRating.count
        let pct = total == 0 ? 0 : Int((Double(right) / Double(total) * 100).rounded())
        let secs = Int(Date().timeIntervalSince(session.started))
        let previous = store.sessions.filter { $0.scopeID == session.scope.id }.sorted { $0.date > $1.date }.dropFirst().first

        ScrollView {
            VStack(spacing: 22) {
                VStack(spacing: 4) {
                    Text(session.scope.name).font(.footnote).foregroundStyle(.secondary)
                    Text("Session done").font(.title.bold())
                }
                ZStack {
                    Circle().stroke(Color(.systemGray5), lineWidth: 16)
                    Circle().trim(from: 0, to: Double(pct) / 100).stroke(pct >= 80 ? Color.green : pct >= 50 ? .blue : .orange, style: StrokeStyle(lineWidth: 16, lineCap: .round)).rotationEffect(.degrees(-90))
                    VStack(spacing: 2) {
                        Text("\(pct)%").font(.system(size: 44, weight: .bold))
                        Text("\(right) of \(total) right").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .frame(width: 180, height: 180)

                HStack(spacing: 8) {
                    stat(String(format: "%d:%02d", secs / 60, secs % 60), "time", .primary)
                    stat("\(session.againSoFar)", "again", .red)
                    if let p = previous {
                        let d = pct - p.percent
                        stat((d >= 0 ? "+" : "") + "\(d)%", "vs last", d >= 0 ? .green : .orange)
                    } else {
                        stat("—", "vs last", .secondary)
                    }
                }

                if let rec = record, rec.perTopic.count > 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("BY SUBTOPIC").font(.caption2.weight(.semibold)).foregroundStyle(.secondary).padding(.horizontal, 4)
                        VStack(spacing: 0) {
                            ForEach(topicsInOrder(rec), id: \.0) { name, v in
                                HStack(spacing: 12) {
                                    Text(name).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
                                    let frac = v[1] == 0 ? 0 : Double(v[0]) / Double(v[1])
                                    Text("\(Int((frac * 100).rounded()))%").font(.subheadline.weight(.semibold)).foregroundStyle(frac >= 0.8 ? .green : .orange)
                                    Text("\(v[0])/\(v[1])").font(.caption).foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 12)
                                Divider().padding(.leading, 16)
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                Color.clear.frame(height: 110)
            }
            .padding(16)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                let missed = session.missed
                if !missed.isEmpty {
                    Button { onRetry(missed) } label: {
                        Text("Retry the \(missed.count) missed").font(.headline).frame(maxWidth: .infinity, minHeight: 54)
                            .foregroundStyle(Color(.systemBackground)).background(Color.primary, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
                Button("Back to subjects") { onDone() }.font(.headline).frame(minHeight: 44)
            }
            .padding(.horizontal, 16).padding(.bottom, 8).background(.bar)
        }
    }

    private func topicsInOrder(_ rec: SessionRecord) -> [(String, [Int])] {
        var out: [(String, [Int])] = []
        for s in store.subjects { for t in s.topics { if let v = rec.perTopic[t.id] { out.append((t.name, v)) } } }
        return out
    }

    private func stat(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.bold()).foregroundStyle(color)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}
