import SwiftUI
import WebKit

struct YouTubePlayerView: UIViewRepresentable {
    enum ContentMode: String {
        case embeddedFrame
        case watchPage
    }

    let videoID: String
    var autoPlay: Bool = false
    var allowInlinePlayback: Bool = true
    var contentMode: ContentMode = .embeddedFrame
    var autoUnmute: Bool = false
    var pauseSignal: Int = 0
    var preferFullscreenOnStart: Bool = false
    var onWatchPageFullscreenExit: (() -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "playerEvent")
        config.allowsInlineMediaPlayback = allowInlinePlayback
        config.allowsPictureInPictureMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .nonPersistent()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.scrollView.isScrollEnabled = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.scrollView.isScrollEnabled = contentMode == .watchPage
        context.coordinator.onWatchPageFullscreenExit = onWatchPageFullscreenExit
        context.coordinator.autoUnmute = autoUnmute
        context.coordinator.autoPlay = autoPlay
        context.coordinator.preferFullscreenOnStart = preferFullscreenOnStart

        if !context.coordinator.hasSyncedInitialPauseSignal {
            context.coordinator.lastPauseSignal = pauseSignal
            context.coordinator.hasSyncedInitialPauseSignal = true
        } else if context.coordinator.lastPauseSignal != pauseSignal {
            context.coordinator.lastPauseSignal = pauseSignal
            context.coordinator.pausePlayback(in: webView)
        }

        let requestSignature = "\(videoID)|autoplay:\(autoPlay)|inline:\(allowInlinePlayback)|mode:\(contentMode.rawValue)|unmute:\(autoUnmute)"
        guard context.coordinator.loadedSignature != requestSignature else { return }
        context.coordinator.loadedSignature = requestSignature

        switch contentMode {
        case .embeddedFrame:
            context.coordinator.restrictMainFrameNavigation = true

            let html = """
            <!doctype html>
            <html>
            <head>
              <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
              <style>
                html, body {
                  margin: 0;
                  width: 100%;
                  height: 100%;
                  overflow: hidden;
                  background: #000;
                }
                #player {
                  border: 0;
                  width: 100%;
                  height: 100%;
                }
              </style>
              <script src="https://www.youtube.com/iframe_api"></script>
            </head>
            <body>
              <div id="player"></div>
              <script>
                var player;
                var shouldAutoUnmute = \(autoUnmute ? "true" : "false");
                function tryAutoUnmute() {
                  if (!shouldAutoUnmute || !player) { return; }
                  try {
                    player.unMute();
                    player.setVolume(100);
                  } catch (e) {}
                }
                function onYouTubeIframeAPIReady() {
                  player = new YT.Player('player', {
                    videoId: '\(videoID)',
                    playerVars: {
                      autoplay: \(autoPlay ? 1 : 0),
                      playsinline: \(allowInlinePlayback ? 1 : 0),
                      rel: 0,
                      modestbranding: 1,
                      enablejsapi: 1
                    },
                    events: {
                      onReady: function(event) {
                        if (\(autoPlay ? "true" : "false")) {
                          try { event.target.playVideo(); } catch (e) {}
                        }
                        tryAutoUnmute();
                        setTimeout(tryAutoUnmute, 300);
                        setTimeout(tryAutoUnmute, 1200);
                      },
                      onStateChange: function(event) {
                        if (event.data === YT.PlayerState.PLAYING) {
                          tryAutoUnmute();
                        }
                      }
                    }
                  });
                }
              </script>
            </body>
            </html>
            """
            webView.loadHTMLString(html, baseURL: URL(string: "https://www.youtube-nocookie.com"))

        case .watchPage:
            context.coordinator.restrictMainFrameNavigation = false

            var components = URLComponents(string: "https://m.youtube.com/watch")
            components?.queryItems = [
                URLQueryItem(name: "v", value: videoID),
                URLQueryItem(name: "autoplay", value: autoPlay ? "1" : nil),
                URLQueryItem(name: "playsinline", value: allowInlinePlayback ? "1" : "0"),
                URLQueryItem(name: "rel", value: "0")
            ]
            guard let url = components?.url else { return }
            webView.load(URLRequest(url: url))
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "playerEvent")
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
        webView.navigationDelegate = nil
        coordinator.loadedSignature = nil
        coordinator.hasSyncedInitialPauseSignal = false
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var loadedSignature: String?
        var restrictMainFrameNavigation = true
        var autoUnmute = false
        var autoPlay = false
        var preferFullscreenOnStart = false
        var lastPauseSignal = 0
        var hasSyncedInitialPauseSignal = false
        var onWatchPageFullscreenExit: (() -> Void)?

        func pausePlayback(in webView: WKWebView) {
            let js = """
            (function() {
              try {
                if (window.player && typeof window.player.pauseVideo === 'function') {
                  window.player.pauseVideo();
                }
              } catch (e) {}

              try {
                const video = document.querySelector('video');
                if (video) { video.pause(); }
              } catch (e) {}

              return true;
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard restrictMainFrameNavigation else {
                decisionHandler(.allow)
                return
            }

            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? false
            guard isMainFrame, let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            let isSafeInlineDocument = url.scheme == "about"
                || url.absoluteString.starts(with: "https://www.youtube-nocookie.com/embed/")
                || url.absoluteString.starts(with: "https://www.youtube.com/embed/")

            decisionHandler(isSafeInlineDocument ? .allow : .cancel)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !restrictMainFrameNavigation else { return }

            // Best effort for watch pages:
            // - auto-unmute once controls are mounted
            // - report fullscreen exit to SwiftUI so parent UI can collapse web content
            let js = """
            (function() {
              function attemptUnmute() {
                try {
                  const video = document.querySelector('video');
                  if (video) {
                    video.muted = false;
                    video.volume = 1;
                  }
                  const nodes = Array.from(document.querySelectorAll('button, [role="button"]'));
                  const button = nodes.find(function(node) {
                    const label = [
                      node.getAttribute('aria-label') || '',
                      node.getAttribute('title') || '',
                      node.textContent || ''
                    ].join(' ').toLowerCase();
                    return label.includes('unmute')
                      || label.includes('turn on sound')
                      || label.includes('sound off');
                  });
                  if (button) { button.click(); }
                } catch (e) {}
              }

              function attemptPlay() {
                try {
                  const video = document.querySelector('video');
                  if (video) {
                    const playResult = video.play();
                    if (playResult && typeof playResult.catch === 'function') {
                      playResult.catch(function() {});
                    }
                  }
                } catch (e) {}
              }

              function attemptEnterFullscreen() {
                try {
                  const video = document.querySelector('video');
                  if (!video) { return; }

                  if (typeof video.webkitEnterFullscreen === 'function') {
                    video.webkitEnterFullscreen();
                    return;
                  }

                  if (typeof video.requestFullscreen === 'function') {
                    const req = video.requestFullscreen();
                    if (req && typeof req.catch === 'function') {
                      req.catch(function() {});
                    }
                  }
                } catch (e) {}
              }

              var shouldAutoUnmute = \(autoUnmute ? "true" : "false");
              var shouldAutoPlay = \(autoPlay ? "true" : "false");
              var shouldStartFullscreen = \(preferFullscreenOnStart ? "true" : "false");
              if (shouldAutoPlay) {
                attemptPlay();
                setTimeout(attemptPlay, 250);
                setTimeout(attemptPlay, 800);
                setTimeout(attemptPlay, 1800);
              }
              if (shouldStartFullscreen) {
                setTimeout(attemptEnterFullscreen, 250);
                setTimeout(attemptEnterFullscreen, 800);
                setTimeout(attemptEnterFullscreen, 1800);
              }
              if (shouldAutoUnmute) {
                attemptUnmute();
                setTimeout(attemptUnmute, 300);
                setTimeout(attemptUnmute, 1200);
              }

              function isFullscreen() {
                try {
                  if (document.fullscreenElement
                    || document.webkitFullscreenElement
                    || document.mozFullScreenElement
                    || document.msFullscreenElement) {
                    return true;
                  }

                  // iOS WebKit commonly drives fullscreen via native video APIs
                  // without updating document fullscreen state.
                  const video = document.querySelector('video');
                  if (video && typeof video.webkitDisplayingFullscreen !== 'undefined') {
                    return !!video.webkitDisplayingFullscreen;
                  }
                } catch (e) {}
                return false;
              }

              var hadFullscreen = false;
              function checkFullscreenTransition() {
                try {
                  var active = isFullscreen();
                  if (active) {
                    hadFullscreen = true;
                  } else if (hadFullscreen) {
                    hadFullscreen = false;
                    if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.playerEvent) {
                      window.webkit.messageHandlers.playerEvent.postMessage('watchPageFullscreenExited');
                    }
                  }
                } catch (e) {}
              }

              document.addEventListener('fullscreenchange', checkFullscreenTransition);
              document.addEventListener('webkitfullscreenchange', checkFullscreenTransition);
              document.addEventListener('mozfullscreenchange', checkFullscreenTransition);
              document.addEventListener('MSFullscreenChange', checkFullscreenTransition);
              setInterval(checkFullscreenTransition, 500);
              return true;
            })();
            """
            webView.evaluateJavaScript(js, completionHandler: nil)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "playerEvent" else { return }
            guard let body = message.body as? String, body == "watchPageFullscreenExited" else { return }
            onWatchPageFullscreenExit?()
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            #if DEBUG
            print("YouTubePlayerView navigation failed: \(error.localizedDescription)")
            #endif
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            #if DEBUG
            print("YouTubePlayerView provisional navigation failed: \(error.localizedDescription)")
            #endif
        }
    }
}
