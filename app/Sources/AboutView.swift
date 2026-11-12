import SwiftUI

struct AboutView: View {
    private let siteURL = URL(string: "https://najam.dev")!

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
            Text("Daily Wallpaper")
                .font(.title2.bold())
            Text("Version 1.0.0")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("by najam.dev")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Made by Najam")
                .font(.callout)
            Link("najam.dev", destination: siteURL)
            Link("Need an app built? najam.dev", destination: siteURL)
                .font(.callout)

            Divider()

            ScrollView {
                Text(Self.licenseText)
                    .font(.caption.monospaced())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(height: 130)

            Button("Close") { WindowManager.shared.close(id: "about") }
        }
        .padding(20)
        .frame(width: 380)
    }

    static let licenseText = """
    MIT License

    Copyright (c) 2026 Najam Ul Hassan, najam.dev

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.
    """
}