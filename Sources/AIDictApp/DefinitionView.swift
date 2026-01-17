import SwiftUI
import AppKit

struct DefinitionView: View {
    @Binding var word: String
    @Binding var definition: String?
    @Binding var isLoading: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Title Header
            HStack {
                Text(word.isEmpty ? "AI Dictionary" : word)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 12)
            
            Divider()
                .padding(.horizontal, 24)
            
            // Content
            Group {
                if let definition = definition {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(definition)
                                .font(.system(size: 15))
                                .lineSpacing(6)
                                .foregroundColor(.primary.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(24)
                    }
                } else if !isLoading {
                    VStack(spacing: 20) {
                        Text("📖")
                            .font(.system(size: 48))
                            .shadow(radius: 4)
                        Text("Force Click a Word")
                            .font(.system(size: 18, weight: .medium))
                        Text("Deep click any word to see its AI definition.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Spacer()
                }
            }
        }
        .frame(width: 450, height: 400)
        .background(VisualEffectView(material: .popover, blendingMode: .behindWindow))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
