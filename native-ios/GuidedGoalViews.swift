import SwiftUI

private enum GuideStyle {
    static let background = Color(red: 0.09, green: 0.09, blue: 0.085)
    static let card = Color(red: 0.15, green: 0.15, blue: 0.14)
    static let accent = Color(red: 0.94, green: 0.59, blue: 0.42)
}
private extension View {
    func guideCard() -> some View {
        padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(GuideStyle.card, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct GuidedGoalsView: View {
    @ObservedObject var store: GuidedGoalStore
    @State private var creating = false
    @State private var title = ""
    @State private var error: String?
    @State private var showArchive = false
    @State private var path: [UUID] = []
    @State private var cloudSettings = false
    @AppStorage("cloudCoachConsent") private var cloudEnabled = false
    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("A goal. A path. Your next step.").font(.title.bold())
                    Text("Talk it through, agree on a direction, and take it one brick at a time.").foregroundStyle(.secondary)
                    if let loadError = store.loadError {
                        Text(loadError).foregroundStyle(.orange)
                        Button("Try loading again") { store.load() }
                    }
                    if !GuidedGoalAI.available {
                        Text(GuidedGoalAI.AIError.unavailable.localizedDescription).font(.callout).guideCard()
                    }
                    Button { creating = true } label: {
                        Label("Start a guided goal", systemImage: "plus").frame(maxWidth: .infinity).padding(8)
                    }.buttonStyle(.borderedProminent).disabled(store.loadError != nil)
                    ForEach(store.goals.filter { $0.archived == showArchive }) { goal in
                        NavigationLink(value: goal.id) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(goal.title).font(.headline).foregroundStyle(.primary)
                                Text(goal.approved ? "\(goal.bricks.filter(\.completed).count) of \(goal.bricks.count) bricks complete" : "Let’s shape your path")
                                    .font(.caption).foregroundStyle(.secondary)
                                if goal.approved { ProgressView(value: Double(goal.bricks.filter(\.completed).count), total: Double(max(1, goal.bricks.count))) }
                            }.guideCard()
                        }
                    }
                    if store.goals.filter({ $0.archived == showArchive }).isEmpty {
                        Text(showArchive ? "No archived goals." : "Your next chapter starts with a conversation.")
                            .foregroundStyle(.secondary).padding(.vertical, 24)
                    }
                    Toggle("Show archived goals", isOn: $showArchive).font(.callout)
                    Button("Cloud AI settings") { cloudSettings = true }
                    Text(cloudEnabled ? "Cloud AI • Conversation context is sent to OpenAI through your backend. You approve outcomes." : "On-device AI • No account required. You approve outcomes.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(24)
            }
            .background(GuideStyle.background).navigationTitle("Guided Goals")
            .sheet(isPresented: $cloudSettings) { CloudCoachSettings() }
            .navigationDestination(for: UUID.self) { id in GuidedGoalDetail(store: store, goalID: id) }
            .sheet(isPresented: $creating) {
                NavigationStack {
                    Form {
                        Section("What would you like to work toward?") {
                            TextField("A goal in your own words", text: $title, axis: .vertical).lineLimit(3...6)
                                .accessibilityIdentifier("guided-goal-title")
                            Text("Learning, a personal project, meal prep, or staying on track. Start with what matters to you.").font(.caption)
                        }
                        if let error = error { Text(error).foregroundStyle(.red) }
                        Button("Start the conversation") {
                            do { let id = try store.create(title); title = ""; error = nil; creating = false; path.append(id) }
                            catch { self.error = error.localizedDescription }
                        }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.count > 300)
                    }.navigationTitle("Your goal")
                        .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { creating = false } } }
                }.preferredColorScheme(.dark)
            }
        }.tint(GuideStyle.accent).preferredColorScheme(.dark)
    }
}

private struct GuidedGoalDetail: View {
    @ObservedObject var store: GuidedGoalStore
    let goalID: UUID
    @State private var preview: GoalBrick?
    @State private var error: String?
    var body: some View {
        Group {
            if let goal = store.goal(goalID) {
                if !goal.approved {
                    GuidedGoalSession(store: store, goalID: goalID, brickID: nil)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 22) {
                            Text("YOUR GOAL").font(.caption.weight(.semibold)).foregroundStyle(GuideStyle.accent)
                            Text(goal.title).font(.largeTitle.bold())
                            Text("\(goal.bricks.filter(\.completed).count) of \(goal.bricks.count) bricks complete").foregroundStyle(.secondary)
                            ProgressView(value: Double(goal.bricks.filter(\.completed).count), total: Double(goal.bricks.count))
                            Text("Your path").font(.title2.bold())
                            ForEach(Array(goal.bricks.enumerated()), id: \.element.id) { index, brick in
                                if goal.unlocked(index) {
                                    NavigationLink {
                                        GuidedGoalSession(store: store, goalID: goalID, brickID: brick.id)
                                    } label: { brickRow(brick, index: index, locked: false) }
                                } else {
                                    Button { preview = brick } label: { brickRow(brick, index: index, locked: true) }
                                }
                            }
                            if let index = goal.nextIndex {
                                NavigationLink {
                                    GuidedGoalSession(store: store, goalID: goalID, brickID: goal.bricks[index].id)
                                } label: { Text("Continue my next brick →").frame(maxWidth: .infinity).padding(8) }
                                    .buttonStyle(.borderedProminent)
                            } else {
                                Label("Your path is complete. Look how far you came.", systemImage: "checkmark.circle.fill").guideCard()
                            }
                            Text("Future bricks are previews. Their conversations use your earlier decisions when you reach them.")
                                .font(.footnote).foregroundStyle(.secondary)
                            Button(goal.archived ? "Restore goal" : "Archive goal") {
                                do { try store.update(goalID) { $0.archived.toggle() } }
                                catch { self.error = error.localizedDescription }
                            }
                            if let error = error { Text(error).foregroundStyle(.orange) }
                        }.padding(24)
                    }.background(GuideStyle.background)
                }
            } else { Text("This goal is no longer available.") }
        }
        .navigationTitle("Your path").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $preview) { brick in
            NavigationStack {
                VStack(alignment: .leading, spacing: 22) {
                    Label("Upcoming brick", systemImage: "lock").foregroundStyle(GuideStyle.accent)
                    Text(brick.title).font(.title.bold())
                    Text(brick.purpose)
                    Text("Finish line").font(.headline)
                    Text(brick.finish).foregroundStyle(.secondary)
                    Text("Complete the earlier bricks first. Their outcomes will shape this session.").font(.callout)
                    Spacer()
                }.padding(24).navigationTitle("Preview")
                    .toolbar { Button("Done") { preview = nil } }
            }.preferredColorScheme(.dark)
        }
    }
    private func brickRow(_ brick: GoalBrick, index: Int, locked: Bool) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: brick.completed ? "checkmark.circle.fill" : locked ? "lock.circle" : "\(index + 1).circle.fill")
                .font(.title2).foregroundStyle(brick.completed ? Color.green : GuideStyle.accent)
            VStack(alignment: .leading, spacing: 7) {
                Text(brick.title).font(.headline).foregroundStyle(.primary)
                Text(brick.purpose).font(.caption).foregroundStyle(.secondary)
                Text(brick.completed ? "Complete · revisit" : locked ? "Locked · preview" : "Ready to start")
                    .font(.caption).foregroundStyle(GuideStyle.accent)
            }
        }.guideCard()
    }
}

private struct GuidedGoalSession: View {
    @ObservedObject var store: GuidedGoalStore
    let goalID: UUID
    let brickID: UUID?
    @State private var input = ""
    @State private var error: String?
    @State private var busy = false
    @State private var work: Task<Void, Never>?
    @State private var completing = false
    @State private var outcome = ""
    @State private var celebration = false
    @State private var editingTitle = false
    @State private var editedTitle = ""
    private var goal: GuidedGoal? { store.goal(goalID) }
    private var brick: GoalBrick? { goal?.bricks.first { $0.id == brickID } }
    private var messages: [GoalMessage] { brick?.messages ?? goal?.discovery ?? [] }
    private var pendingReply: Bool { messages.last?.isUser == true }
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(brickID == nil ? "LET’S FIND YOUR DIRECTION" : "GUIDED BRICK")
                        .font(.caption.weight(.semibold)).foregroundStyle(GuideStyle.accent)
                    Text(brick?.title ?? goal?.title ?? "Your goal").font(.title.bold())
                    if let brick = brick {
                        Text(brick.purpose).foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Finish line").font(.headline)
                            Text(brick.finish)
                        }.guideCard()
                        if let goal = goal, let i = goal.bricks.firstIndex(where: { $0.id == brickID }), i > 0 {
                            DisclosureGroup("What carries forward") {
                                ForEach(Array(goal.bricks.prefix(i))) { previous in
                                    VStack(alignment: .leading) {
                                        Text(previous.title).bold()
                                        Text(previous.outcome).foregroundStyle(.secondary)
                                    }.padding(.vertical, 6)
                                }
                            }.guideCard()
                        }
                        if brick.completed {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Brick complete", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                                Text(brick.outcome)
                            }.guideCard()
                        }
                    }
                    ForEach(messages) { message in
                        HStack {
                            if message.isUser { Spacer(minLength: 28) }
                            Text(message.text).textSelection(.enabled).padding(16)
                                .background(message.isUser ? GuideStyle.accent.opacity(0.24) : GuideStyle.card,
                                            in: RoundedRectangle(cornerRadius: 17))
                            if !message.isUser { Spacer(minLength: 18) }
                        }
                    }
                    if messages.isEmpty && brickID != nil {
                        Button("Start this conversation") { runReply() }.buttonStyle(.borderedProminent).disabled(busy)
                    }
                    if busy {
                        HStack { ProgressView(); Text(CloudCoach.enabled ? "Your guide is thinking…" : "Thinking on your iPhone…"); Spacer(); Button("Cancel") { work?.cancel() } }
                    }
                    if let error = error {
                        Text(error).foregroundStyle(.orange)
                    }
                    if pendingReply && !busy {
                        Button("Get guide’s response") { runReply() }.buttonStyle(.bordered)
                    }
                    if brickID == nil, let goal = goal {
                        if !goal.bricks.isEmpty {
                            Text("Your proposed path").font(.title2.bold())
                            ForEach(goal.bricks) { item in
                                VStack(alignment: .leading, spacing: 9) {
                                    Text(item.title).font(.headline)
                                    Text(item.purpose)
                                    Text("Complete when: \(item.finish)").font(.caption).foregroundStyle(.secondary)
                                }.guideCard()
                            }
                            Button("Agree & start this path") {
                                do { try store.approve(goalID) } catch { self.error = error.localizedDescription }
                            }.buttonStyle(.borderedProminent).disabled(busy)
                            Text("Want changes? Tell the guide below, then draft again. Your path is not locked in until you agree.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Button(goal.bricks.isEmpty ? "Draft my path" : "Redraft with my changes") { draftPath() }
                            .buttonStyle(.bordered)
                            .disabled(busy || !goal.discovery.contains(where: \.isUser) || pendingReply)
                        Button("Edit goal wording") { editedTitle = goal.title; editingTitle = true }.disabled(busy)
                    } else if let brick = brick, brick.canReviewCompletion {
                        Text("Your outcome is ready to review. Keep chatting if you want to change anything.")
                            .font(.callout).foregroundStyle(.secondary)
                        Button("Review this outcome") {
                            outcome = brick.proposedOutcome ?? ""
                            completing = true
                        }.buttonStyle(.borderedProminent).disabled(busy || pendingReply)
                    }
                    Text(CloudCoach.enabled ? "Cloud AI can make mistakes. This conversation and relevant goal context are sent through your backend to OpenAI. No web browsing or external actions." : "On-device AI can make mistakes. No web browsing or external actions. Full chats stay saved; compact notes and recent messages carry into each response.")
                        .font(.caption).foregroundStyle(.secondary)
                    Color.clear.frame(height: 1).id("bottom")
                }.padding(24)
            }
            .onChange(of: messages.count) { _, _ in withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
        }
        .background(GuideStyle.background)
        .safeAreaInset(edge: .bottom) {
            if brick?.completed != true {
                HStack(alignment: .bottom, spacing: 12) {
                    TextField("Tell me what you think…", text: $input, axis: .vertical).lineLimit(1...4)
                        .padding(12).background(GuideStyle.card, in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityIdentifier("guided-message")
                    Button { send() } label: { Image(systemName: "arrow.up.circle.fill").font(.largeTitle) }
                        .accessibilityLabel("Send message")
                        .disabled(busy || pendingReply || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || input.count > 1000)
                }.padding(16).background(GuideStyle.background)
            }
        }
        .onDisappear { work?.cancel() }
        .sheet(isPresented: $completing) {
            NavigationStack {
                Form {
                    Section("What did you decide, learn, or do?") {
                        Text("Review the AI notes below. Replace them with the actual outcome, including anything you want the next brick to know.")
                        TextEditor(text: $outcome).frame(minHeight: 180)
                        Text("Only confirm once you’ve met this brick’s finish line. Real-world actions are not completed by chatting.").font(.caption)
                    }
                    if let error = error { Text(error).foregroundStyle(.red) }
                    Button("Confirm completion & unlock next") {
                        do {
                            if let brickID = brickID { try store.complete(goalID, brickID: brickID, outcome: outcome) }
                            completing = false
                            celebration = true
                        } catch { self.error = error.localizedDescription }
                    }.disabled(outcome.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || outcome.count > 1200)
                }.navigationTitle("Lay this brick")
                    .toolbar { Button("Cancel") { completing = false } }
            }.preferredColorScheme(.dark)
        }
        .alert("Another brick laid.", isPresented: $celebration) {
            Button("Keep going", role: .cancel) { }
        } message: { Text("Your outcome is saved. Return to Your path to start the next unlocked brick, or come back later.") }
        .sheet(isPresented: $editingTitle) {
            NavigationStack {
                Form {
                    TextField("Goal", text: $editedTitle, axis: .vertical)
                    Button("Save goal wording") {
                        do {
                            try store.update(goalID) { goal in goal.title = editedTitle.trimmingCharacters(in: .whitespacesAndNewlines); goal.bricks = [] }
                            editingTitle = false
                        } catch { self.error = error.localizedDescription }
                    }.disabled(editedTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || editedTitle.count > 300)
                }.navigationTitle("Your goal").toolbar { Button("Cancel") { editingTitle = false } }
            }.preferredColorScheme(.dark)
        }
    }
    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !busy, !pendingReply, !text.isEmpty, text.count <= 1000 else { return }
        do {
            try store.update(goalID) { goal in
                let message = GoalMessage(isUser: true, text: text)
                if let brickID = brickID, let i = goal.bricks.firstIndex(where: { $0.id == brickID }) {
                    guard goal.unlocked(i), !goal.bricks[i].completed else { throw GuidedGoalStore.StoreError.locked }
                    goal.bricks[i].messages.append(message)
                } else if brickID == nil { goal.discovery.append(message); goal.bricks = [] }
            }
            input = ""
            runReply()
        } catch { self.error = error.localizedDescription }
    }
    private func runReply() {
        guard !busy, let snapshot = goal else { return }
        let currentBrick = brick
        busy = true; error = nil
        work = Task { @MainActor in
            defer { busy = false }
            do {
                let reply = try await GuidedGoalAI.reply(goal: snapshot, brick: currentBrick)
                try Task.checkCancellation()
                try store.update(goalID) { goal in
                    let message = GoalMessage(isUser: false, text: reply.text)
                    if let brickID = brickID, let i = goal.bricks.firstIndex(where: { $0.id == brickID }) {
                        goal.bricks[i].messages.append(message); goal.bricks[i].memory = reply.memory
                        goal.bricks[i].readiness = reply.status
                        goal.bricks[i].proposedOutcome = reply.outcome
                    } else if brickID == nil { goal.discovery.append(message); goal.memory = reply.memory }
                }
            } catch {
                if !Task.isCancelled { self.error = "\(error.localizedDescription) Your saved messages are unchanged. You can retry." }
            }
        }
    }
    private func draftPath() {
        guard !busy, let snapshot = goal else { return }
        busy = true; error = nil
        work = Task { @MainActor in
            defer { busy = false }
            do {
                let path = try await GuidedGoalAI.plan(goal: snapshot)
                try Task.checkCancellation()
                try store.update(goalID) { goal in
                    guard !goal.approved else { throw GuidedGoalStore.StoreError.invalid }
                    goal.bricks = path
                }
            } catch {
                if !Task.isCancelled { self.error = "\(error.localizedDescription) Tap Draft my path to retry." }
            }
        }
    }
}
