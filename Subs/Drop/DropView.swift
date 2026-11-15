import AppKit
import SwiftUI

/// The drop window: a small panel that opens from the status menu. Drop
/// videos on it, or on the status item itself.
@MainActor
final class DropWindowController: NSWindowController {
    init(queue: SubtitleQueue, settings: SettingsStore, openSettings: @escaping () -> Void) {
        let host = NSHostingController(rootView: DropView(queue: queue, settings: settings, openSettings: openSettings))
        let window = NSPanel(contentViewController: host)
        window.title = "Subs"
        window.styleMask = [.titled, .closable, .fullSizeContentView, .utilityWindow]
        window.titlebarAppearsTransparent = true
        window.isFloatingPanel = true
        window.hidesOnDeactivate = false
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 360, height: 380))
        window.setFrameAutosaveName("Subs.Drop")
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func show() {
        if window?.isVisible != true, window?.setFrameUsingName(window?.frameAutosaveName ?? "") != true {
            window?.center()
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct DropView: View {
    @ObservedObject var queue: SubtitleQueue
    @ObservedObject var settings: SettingsStore
    let openSettings: () -> Void
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 14) {
            dropZone
            if !queue.jobs.isEmpty { recentJobs }
            Spacer(minLength: 0)
            footer
        }
        .padding(16)
        .padding(.top, 12)
        .frame(minWidth: 320, minHeight: 300)
        .contentShape(Rectangle())
        .dropDestination(for: URL.self) { urls, _ in
            queue.accept(urls)
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
    }

    private var dropZone: some View {
        VStack(spacing: 10) {
            Image(systemName: isDropTargeted ? "arrow.down.circle.fill" : "film.stack")
                .font(.system(size: 36, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .contentTransition(.symbolEffect(.replace))
            VStack(spacing: 3) {
                Text(isDropTargeted ? "Let go to find subtitles" : "Drop video files here")
                    .font(.headline)
                Text("MKV, MP4, AVI, MOV, and more")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button("Choose Videos…") { queue.chooseVideos() }
                .controlSize(.small)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isDropTargeted ? Color.accentColor.opacity(0.12) : Color(nsColor: .controlBackgroundColor).opacity(0.65))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isDropTargeted ? Color.accentColor : Color.secondary.opacity(0.28),
                    style: StrokeStyle(lineWidth: isDropTargeted ? 2 : 1, dash: [7, 5])
                )
        }
        .animation(.snappy(duration: 0.2), value: isDropTargeted)
    }

    private var recentJobs: some View {
        VStack(spacing: 0) {
            HStack {
                Text("RECENT")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") { queue.clearFinished() }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)

            let shown = Array(queue.jobs.prefix(4))
            VStack(spacing: 0) {
                ForEach(Array(shown.enumerated()), id: \.element.id) { offset, job in
                    JobRow(job: job, reveal: queue.reveal)
                    if offset < shown.count - 1 { Divider().padding(.leading, 34) }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.75), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private var footer: some View {
        HStack {
            Label(settings.languageName, systemImage: "globe")
            Spacer()
            if settings.isConfigured {
                Text("OpenSubtitles configured")
            } else {
                Button("Set up OpenSubtitles…", action: openSettings)
                    .buttonStyle(.link)
            }
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
                Text(job.detail)
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
        .padding(.vertical, 8)
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

    private var detailColor: Color {
        if case .failed = job.stage { return .red }
        return .secondary
    }
}
