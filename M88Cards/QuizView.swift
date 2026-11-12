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
                        Text("\(min(session.index + 1, session.total)) of \(session.total)").font(.caption).foregroundStyle(.secondary)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        Label("\(session.rightSoFar)", systemImage: "checkmark").foregroundStyle(.green)
                        Label("\(session.againSoFar)", systemImage: "arrow.counterclockwise").foregroundStyle(.red)
                    }
                    .font(.footnote.weight(.semibold)).labelStyle(.titleAndIcon)
                }
            }
        }
        .fullScreenCover(item: $retry) { scope in QuizView(session: QuizSession(scope: scope)) }
        .onChange(of: retry) { _, new in if new == nil && session.finished { dismiss() } }
    }

    private func cardScreen(_ card: Card) -> some View {
        VStack(spacing: 14) {
            ProgressView(value: session.progress).tint(.primary).padding(.horizontal, 20)

            Button { withAnimation(.snappy) { session.revealed = true } } label: {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(card.q).font(.title2.weight(.semibold)).multilineTextAlignment(.leading)
                        if session.revealed {
                            Divider()
                            Text(card.a).font(.title3)
                            if let n = card.note { Text(n).font(.caption).foregroundStyle(.tertiary) }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)

            if session.revealed {
                HStack(spacing: 8) {
                    ForEach(Rating.allCases, id: \.self) { r in
                        Button { answer(r) } label: {
                            VStack(spacing: 2) {
                                Text(r.label).font(.subheadline.weight(.bold))
                                Text(Scheduler.preview(r, for: store.state(for: card))).font(.caption2).opacity(0.85)
                            }
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(r.tint, in: RoundedRectangle(cornerRadius: 14))
                            .foregroundStyle(.white)
                        }
                    }
                }
                .padding(.horizontal, 16)
            } else {
                Button { withAnimation(.snappy) { session.revealed = true } } label: {
                    Text("Show answer").font(.headline).frame(maxWidth: .infinity, minHeight: 54)
                        .foregroundStyle(Color(.systemBackground)).background(Color.primary, in: RoundedRectangle(cornerRadius: 14))
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
