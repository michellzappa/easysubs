import SwiftUI

struct ContentView: View {
    @StateObject private var settings: SettingsStore
    @StateObject private var appState: AppState
    @State private var isDropTargeted = false
    @State private var showSettings = false

    init() {
        let store = SettingsStore()
        _settings = StateObject(wrappedValue: store)
        _appState = StateObject(wrappedValue: AppState(settings: store))
    }

    var body: some View {
        VStack(spacing: 18) {
            header
            dropZone
            if !appState.jobs.isEmpty { recentJobs }
            Spacer(minLength: 0)
            footer
        }
        .padding(22)
        .background {
            LinearGradient(
                colors: [Color(nsColor: .windowBackgroundColor), Color.accentColor.opacity(0.045)],
                startPoint: .top,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
        .contentShape(Rectangle())
        .dropDestination(for: URL.self) { urls, _ in
            appState.accept(urls)
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings, isPresented: $showSettings)
        }
        .onChange(of: appState.wantsSetup) { _, wantsSetup in
            if wantsSetup {
                showSettings = true
                appState.wantsSetup = false
            }
        }
        .onAppear {
            if !settings.isConfigured { showSettings = true }
        }
    }

    private var header: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(Color.accentColor.gradient)
                Image(systemName: "captions.bubble.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 50, height: 50)
            .shadow(color: Color.accentColor.opacity(0.22), radius: 10, y: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text("EasySubs")
                    .font(.title2.weight(.bold))
                Text(appState.isProcessing ? "Finding the best match…" : "Drop a video. Get its subtitles.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Settings")
        }
    }

    private var dropZone: some View {
        VStack(spacing: 12) {
            Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "film.stack")
                .font(.system(size: 42, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .contentTransition(.symbolEffect(.replace))
            VStack(spacing: 4) {
                Text(isDropTargeted ? "Let go to find subtitles" : "Drop video files here")
                    .font(.headline)
                Text("MKV, MP4, AVI, MOV, and more")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Choose Videos…") { appState.chooseVideos() }
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, minHeight: 175)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor).opacity(0.65))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.28),
                    style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1, dash: [7, 5])
                )
        }
        .scaleEffect(isDropTargeted ? 1.012 : 1)
        .animation(.snappy(duration: 0.2), value: isDropTargeted)
    }

    private var recentJobs: some View {
        VStack(spacing: 0) {
            HStack {
                Text("RECENT")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") { appState.clearFinished() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)

            VStack(spacing: 0) {
                ForEach(Array(appState.jobs.prefix(4).enumerated()), id: \.element.id) { offset, job in
                    JobRow(job: job, reveal: appState.reveal)
                    if offset < min(appState.jobs.count, 4) - 1 { Divider().padding(.leading, 34) }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.75), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var footer: some View {
        HStack {
            Label(settings.languageName, systemImage: "globe")
            Spacer()
            Text(settings.isConfigured ? "OpenSubtitles configured" : "Setup required")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

private struct JobRow: View {
    let job: SubtitleJob
    let reveal: (URL) -> Void

    var body: some View {
        HStack(spacing: 10) {
            statusIcon
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(job.videoURL.lastPathComponent)
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(detailColor)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            if case let .saved(url) = job.stage {
                Button { reveal(url) } label: { Image(systemName: "folder") }
                    .buttonStyle(.borderless)
                    .help("Show subtitle in Finder")
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
    }

    @ViewBuilder private var statusIcon: some View {
        switch job.stage {
        case .queued:
            Image(systemName: "clock").foregroundStyle(.secondary)
        case .hashing, .searching, .downloading:
            ProgressView().controlSize(.small)
        case .saved:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .skipped:
            Image(systemName: "checkmark.circle").foregroundStyle(.secondary)
        case .failed:
            Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
        }
    }

    private var detail: String {
        switch job.stage {
        case .queued: "Waiting"
        case .hashing: "Reading video fingerprint…"
        case .searching: "Searching OpenSubtitles…"
        case .downloading: job.matchDescription ?? "Downloading…"
        case .saved: "Saved beside the video"
        case .skipped: "Subtitle already exists"
        case let .failed(message): message
        }
    }

    private var detailColor: Color {
        if case .failed = job.stage { return .red }
        return .secondary
    }
}
