import SwiftUI

struct QuizView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var session: QuizSession
    @State private var retry: QuizScope?

    var body: some View {
        NavigationStack {
            Group {
                if session.finished || session.current == nil {
                    ScoreView(session: session, onRetry: { missed in retry = QuizScope(id: "missed", name: "Missed · \(session.scope.name)", cards: missed) }, onDone: { dismiss() })
                } else if let card = session.current {
                    cardScreen(card)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { session.finish(store: store); dismiss() } label: { Image(systemName: "xmark") }
                }
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text(session.scope.name).font(.subheadline.weight(.semibold)).lineLimit(1)
                        Text("Card \(min(session.index + 1, session.total)) of \(session.total)").font(.caption).foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 6) {
                        Text("\(session.rightSoFar)").padding(.horizontal, 8).padding(.vertical, 3).background(.green.opacity(0.15), in: RoundedRectangle(cornerRadius: 8)).foregroundStyle(.green)
                        Text("\(session.againSoFar)").padding(.horizontal, 8).padding(.vertical, 3).background(.red.opacity(0.15), in: RoundedRectangle(cornerRadius: 8)).foregroundStyle(.red)
                    }
                    .font(.footnote.weight(.semibold))
                }
            }
        }
        .fullScreenCover(item: $retry) { scope in QuizView(session: QuizSession(scope: scope)) }
        .onChange(of: retry) { _, new in if new == nil && session.finished { dismiss() } }
    }

    private func cardScreen(_ card: Card) -> some View {
        VStack(spacing: 16) {
            ProgressView(value: session.progress).tint(.accentColor).padding(.horizontal, 16)

            Button { withAnimation(.snappy) { session.revealed = true } } label: {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("QUESTION").font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                        Text(card.q).font(.title2.weight(.semibold)).multilineTextAlignment(.leading)
                        if session.revealed {
                            Divider()
                            Text("ANSWER").font(.caption2.weight(.semibold)).foregroundStyle(Color.accentColor)
                            Text(card.a).font(.title3)
                            if let n = card.note { Text(n).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                }
                .overlay(alignment: .bottom) {
                    if !session.revealed {
                        Label("Tap to reveal", systemImage: "plus.circle").font(.footnote).foregroundStyle(.secondary).padding(.bottom, 20)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
                .shadow(color: .black.opacity(0.08), radius: 10, y: 2)
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)

            if session.revealed {
                HStack(spacing: 8) {
                    ForEach(Rating.allCases, id: \.self) { r in
                        Button { answer(r) } label: {
                            VStack(spacing: 2) {
                                Text(r.label).font(.subheadline.weight(.semibold))
                                Text(Scheduler.preview(r, for: store.state(for: card))).font(.caption2).opacity(0.8)
                            }
                            .frame(maxWidth: .infinity, minHeight: 60)
                            .background(r.tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(r.tint)
                        }
                    }
                }
                .padding(.horizontal, 16)
            } else {
                Button { withAnimation(.snappy) { session.revealed = true } } label: {
                    Text("Show answer").font(.headline).frame(maxWidth: .infinity, minHeight: 54)
                        .foregroundStyle(Color(.systemBackground)).background(Color.primary, in: RoundedRectangle(cornerRadius: 16))
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.top, 8).padding(.bottom, 12)
    }

    private func answer(_ r: Rating) {
        withAnimation(.snappy) { session.answer(r, store: store) }
        store.save()
    }
}
