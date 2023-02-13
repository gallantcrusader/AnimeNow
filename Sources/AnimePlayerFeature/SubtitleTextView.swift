//
//  SubtitleTextView.swift
//  Anime Now!
//
//  Created by ErrorErrorError on 10/30/22.
//
//

import SwiftUI
import SwiftWebVTT
import Utilities
import ViewComponents

// MARK: - SubtitleTextView

public struct SubtitleTextView: View {
    public enum Size: CGFloat {
        case small = 0.75
        case normal = 1.0
        case large = 1.25
    }

    public struct Options: Hashable {
        let fontSize: Size
        var shadowColor: Color
        var shadowOffset: CGFloat
        var strokeColor: Color
        var strokeWidth: CGFloat
        var backgroundColor: Color
        var backgroundRadius: CGFloat
        var backgroundPadding: CGFloat

        public init(
            fontSize: Size = .normal,
            shadowColor: Color = .clear,
            shadowOffset: CGFloat = 0,
            strokeColor: Color = .clear,
            strokeWidth: CGFloat = 0,
            backgroundColor: Color = .clear,
            backgroundRadius: CGFloat = 0,
            backgroundPadding: CGFloat = 0
        ) {
            self.fontSize = fontSize
            self.shadowColor = shadowColor
            self.shadowOffset = shadowOffset
            self.strokeColor = strokeColor
            self.strokeWidth = strokeWidth
            self.backgroundColor = backgroundColor
            self.backgroundRadius = backgroundRadius
            self.backgroundPadding = backgroundPadding
        }
    }

    @StateObject
    private var viewModel = ViewModel()

    var url: URL?
    var progress: Double = .zero
    var duration: Double = .zero
    var options: Options = .defaultBoxed

    public init(
        url: URL? = nil,
        progress: Double = .zero,
        duration: Double = .zero,
        options: Options = .defaultBoxed
    ) {
        self.url = url
        self.progress = progress
        self.duration = duration
        self.options = options
    }

    public var body: some View {
        GeometryReader { reader in
            VStack(
                alignment: .center,
                spacing: 0
            ) {
                Spacer()

                if let cue = viewModel.vtt.value?.bounds(for: progress * duration)?.first {
                    Text(cue.text)
                        .font(
                            .system(
                                size: (DeviceUtil.isPhone ? 0.05 : 0.04) *
                                    reader.size.height *
                                    options.fontSize.rawValue,
                                weight: .semibold
                            )
                        )
                        .multilineTextAlignment(.center)
                        .padding(options.backgroundPadding)
                        .background(
                            options.backgroundColor
                                .cornerRadius(options.backgroundRadius)
                        )
                }
                Spacer(minLength: reader.size.height * 0.075)
                    .fixedSize()
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity
            )
        }
        .onChange(of: url) { viewModel.updateURL($0) }
    }
}

public extension SubtitleTextView.Options {
    static let defaultBoxed: Self = .init(
        backgroundColor: .black.opacity(0.5),
        backgroundRadius: 8,
        backgroundPadding: 8
    )

    static let defaultStroke: Self = .init(
        shadowColor: .black,
        shadowOffset: 2,
        strokeColor: .black,
        strokeWidth: 3
    )
}

// MARK: - SubtitleTextView.ViewModel

extension SubtitleTextView {
    class ViewModel: ObservableObject {
        var subtitleURL: URL?
        @Published
        var vtt = Loadable<WebVTT>.idle

        private var subtitlesTask: URLSessionDataTask?

        func updateURL(_ url: URL?) {
            guard let url else {
                subtitlesTask?.cancel()
                subtitleURL = nil
                vtt = .idle
                return
            }

            guard url != subtitleURL else {
                return
            }
            subtitlesTask?.cancel()
            subtitleURL = url
            vtt = .loading

            subtitlesTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
                do {
                    if error != nil {
                        throw URLError(.badServerResponse)
                    }

                    guard let data else {
                        throw URLError(.badServerResponse)
                    }

                    guard let stringVal = String(data: data, encoding: .utf8) else {
                        throw URLError(.badServerResponse)
                    }

                    let parser = WebVTTParser(string: stringVal)

                    self?.updateState(.success(try parser.parse()))
                } catch {
                    self?.updateState(.failed(error))
                }
            }

            subtitlesTask?.resume()
        }

        private func updateState(_ loadable: Loadable<WebVTT>) {
            DispatchQueue.main.async {
                self.vtt = loadable
            }
        }
    }
}

// MARK: - WebVTT + Equatable

extension WebVTT: Equatable {
    public static func == (lhs: WebVTT, rhs: WebVTT) -> Bool {
        lhs.cues == rhs.cues
    }
}

// MARK: - WebVTT.Cue + Hashable

extension WebVTT.Cue: Hashable {
    public static func == (lhs: WebVTT.Cue, rhs: WebVTT.Cue) -> Bool {
        lhs.timing == rhs.timing &&
            lhs.text == rhs.text
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(text)
        hasher.combine(timing)
    }
}

// MARK: - WebVTT.Timing + Hashable

extension WebVTT.Timing: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(start)
        hasher.combine(end)
    }

    public static func == (lhs: WebVTT.Timing, rhs: WebVTT.Timing) -> Bool {
        lhs.start == rhs.start &&
            lhs.end == rhs.end
    }
}

extension WebVTT {
    func bounds(for timeStamp: TimeInterval) -> [Cue]? {
        cues.filter { $0.timeStart <= timeStamp && timeStamp <= $0.timeEnd }
    }
}

// MARK: - SubtitleTextView_Previews

struct SubtitleTextView_Previews: PreviewProvider {
    static var previews: some View {
        SubtitleTextView(
            url: .init(
                string: "https://raw.githubusercontent.com/SwiftCommunityPodcast/podcast/master/Shownotes/Episode1-Transcript.vtt"
            ),
            progress: 0.2,
            duration: 1.0
        )
        .frame(width: 1_280, height: 720)
    }
}
