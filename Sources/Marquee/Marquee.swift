//
//  Marquee.swift
//
//
//  Created by CatchZeng on 2020/11/23.
//

import SwiftUI

public enum MarqueeDirection {
    case right2left
    case left2right
}

public enum MarqueeBoundary {
    /// Keeps the content visible and uses the inner boundary for the animation.
    case inner
    /// Moves the content outside of the view and uses the outer boundary for the animation.
    case outer
}

public enum MarqueeState {
    case idle
    case ready
    case animating
}

public class MarqueeViewModel: ObservableObject {
    @Published var state: MarqueeState = .idle
    @Published var contentWidth: CGFloat = 0
    @Published var contentHeight: CGFloat = 0
    @Published var isAppear = false
    
    public init() {}
}

public struct Marquee<Content> : View where Content : View {
    @Environment(\.marqueeDuration) var duration
    @Environment(\.marqueeDelay) var delay
    @Environment(\.marqueeAutoreverses) var autoreverses: Bool
    @Environment(\.marqueeDirection) var direction: MarqueeDirection
    @Environment(\.marqueeWhenNotFit) var stopWhenNotFit: Bool
    @Environment(\.marqueeIdleAlignment) var idleAlignment: HorizontalAlignment
    @Environment(\.marqueeBoundary) var boundary: MarqueeBoundary
    @Environment(\.marqueeLoopCount) var loopCount: Int

    private var content: () -> Content
    @ObservedObject private var viewModel: MarqueeViewModel
    
    init(viewModel: MarqueeViewModel = .init(), @ViewBuilder content: @escaping () -> Content) {
        self.content = content
        self.viewModel = viewModel
    }
    
    public var body: some View {
        GeometryReader { proxy in
            VStack {
                if viewModel.isAppear {
                    content()
                        .background(GeometryBackground())
                        .fixedSize()
                        .myOffset(x: offsetX(proxy: proxy), y: 0)
                } else {
                    Text("")
                }
            }
            .onPreferenceChange(HeightKey.self, perform: { value in
                self.viewModel.contentHeight = value
                resetAnimation(
                    duration: duration,
                    delay: delay,
                    autoreverses: autoreverses,
                    proxy: proxy
                )
            })
            .onPreferenceChange(WidthKey.self, perform: { value in
                self.viewModel.contentWidth = value
                resetAnimation(
                    duration: duration,
                    delay: delay,
                    autoreverses: autoreverses,
                    proxy: proxy
                )
            })
            .onAppear {
                self.viewModel.isAppear = true
                resetAnimation(
                    duration: duration,
                    delay: delay,
                    autoreverses: autoreverses,
                    proxy: proxy
                )
            }
            .onDisappear {
                self.viewModel.isAppear = false
            }
            .onChange(of: duration) { [] newDuration in
                resetAnimation(
                    duration: newDuration,
                    delay: delay,
                    autoreverses: autoreverses,
                    proxy: proxy
                )
            }
            .onChange(of: delay) { [] newDelay in
                resetAnimation(
                    duration: duration,
                    delay: newDelay,
                    autoreverses: autoreverses,
                    proxy: proxy
                )
            }
            .onChange(of: autoreverses) { [] newAutoreverses in
                resetAnimation(
                    duration: duration,
                    delay: delay,
                    autoreverses: newAutoreverses,
                    proxy: proxy
                )
            }
            .onChange(of: direction) { [] _ in
                resetAnimation(
                    duration: duration,
                    delay: delay,
                    autoreverses: autoreverses,
                    proxy: proxy
                )
            }
        }
        .frame(height: viewModel.contentHeight)
        .onChange(of: viewModel.state) { newValue in
            print("Marquee state changed to \(newValue)")
        }
    }
    
    private func offsetX(proxy: GeometryProxy) -> CGFloat {
        switch self.viewModel.state {
        case .idle:
            switch idleAlignment {
            case .center:
                return 0.5*(proxy.size.width-viewModel.contentWidth)
            case .trailing:
                return proxy.size.width-viewModel.contentWidth
            case .leading:
                return 0
            default:
                return 0
            }
        case .ready:
            return (direction == .right2left)
                            ? boundary == .outer ? proxy.size.width : 0
                            : -viewModel.contentWidth
        case .animating:
            return (direction == .right2left)
                            ? boundary == .outer ? -viewModel.contentWidth : proxy.size.width - viewModel.contentWidth
                            : proxy.size.width
        }
    }
    
    private func resetAnimation(duration: Double, delay: Double, autoreverses: Bool, proxy: GeometryProxy) {
        if duration == 0 || duration == Double.infinity {
            stopAnimation()
        } else {
            startAnimation(duration: duration, delay: delay, autoreverses: autoreverses, proxy: proxy)
        }
    }
    
    private func startAnimation(duration: Double, delay: Double, autoreverses: Bool, proxy: GeometryProxy) {
        let isNotFit = viewModel.contentWidth < proxy.size.width
        if stopWhenNotFit && isNotFit {
            stopAnimation()
            return
        }
        
        withAnimation(.instant) {
            self.viewModel.state = .ready
            let animation = Animation
                .linear(duration: duration)
                .delay(delay)
                .repeatCount(loopCount, autoreverses: autoreverses)
            withAnimation(animation) {
                self.viewModel.state = .animating
                // update animation state after loopcount * duration
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(loopCount) * duration) {
                    self.viewModel.state = .idle
                }
            }
        }
    }
    
    private func stopAnimation() {
        withAnimation(.instant) {
            self.viewModel.state = .idle
        }
    }
}

struct Marquee_Previews: PreviewProvider {
    static var previews: some View {
        Marquee {
            HStack {
                Text("Hello World!")
                    .fontWeight(.bold)
                    .font(.system(size: 40))
                    .padding()
                
                Text("Hello World!")
                    .fontWeight(.regular)
                    .font(.system(size: 40))
            }
        }
        .marqueeLoopCount(2)
        .marqueeIdleAlignment(.trailing)
        
        Marquee {
            VStack {
                Text("Hello World!")
                    .fontWeight(.bold)
                    .font(.system(size: 40))
                    .padding()
                
                Text("Hello World!")
                    .fontWeight(.regular)
                    .font(.system(size: 40))
            }
        }
        .marqueeLoopCount(.max)
    }
}
