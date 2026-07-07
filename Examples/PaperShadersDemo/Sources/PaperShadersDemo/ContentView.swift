import Foundation
import PaperShaders
import PaperShadersSwiftUI
import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Catalog-driven showcase for every ported shader. New `ShaderCatalog`
/// entries appear automatically in the sidebar and inherit generic controls
/// for motion, sizing, colors and scalar uniforms.
struct ContentView: View {
  @State private var selectedShader: String? = ShaderCatalog.all.first?.descriptor.name
  @State private var selectedPreset = 0
  @State private var uniforms: [UniformValue] = []
  @State private var sizing = ShaderSizingParams.defaultObject
  @State private var speed: Double = 0
  @State private var frame: Double = 0
  @State private var renderOptions = ShaderRenderOptions.interactive
  @State private var renderMetrics = ShaderRenderMetrics.empty

  private var selectedEntry: ShaderCatalogEntry? {
    ShaderCatalog.all.first { $0.descriptor.name == selectedShader }
  }

  var body: some View {
    NavigationSplitView {
      List(ShaderCatalog.all, id: \.descriptor.name, selection: $selectedShader) { entry in
        ShaderListRow(entry: entry)
      }
      .navigationTitle("Paper Shaders")
    } detail: {
      if let entry = selectedEntry {
        ShaderDetailView(
          entry: entry,
          selectedPreset: $selectedPreset,
          uniforms: $uniforms,
          sizing: $sizing,
          speed: $speed,
          frame: $frame,
          renderOptions: $renderOptions,
          renderMetrics: $renderMetrics
        )
      } else {
        VStack(spacing: 10) {
          Image(systemName: "sparkles")
            .font(.largeTitle)
            .foregroundStyle(.secondary)
          Text("Select a shader")
            .font(.title3)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .onAppear(perform: resetControls)
    .onChange(of: selectedShader) { _ in
      selectedPreset = 0
      resetControls()
    }
    .onChange(of: selectedPreset) { _ in
      resetControls()
    }
  }

  private func resetControls() {
    guard let entry = selectedEntry, !entry.presets.isEmpty else { return }
    let safeIndex = min(selectedPreset, entry.presets.count - 1)
    let preset = entry.presets[safeIndex]
    selectedPreset = safeIndex
    uniforms = preset.uniforms
    sizing = preset.sizing
    speed = preset.speed
    frame = 0
    renderMetrics = .empty
  }
}

private struct ShaderListRow: View {
  let entry: ShaderCatalogEntry

  var body: some View {
    HStack(spacing: 12) {
      ShaderThumbnail(name: entry.descriptor.name, size: 54)
      VStack(alignment: .leading, spacing: 3) {
        Text(entry.descriptor.name)
          .lineLimit(1)
        Text("\(entry.presets.count) presets")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .padding(.vertical, 4)
  }
}

private struct ShaderThumbnail: View {
  let name: String
  let size: CGFloat

  var body: some View {
    thumbnail
      .frame(width: size, height: size)
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .stroke(.primary.opacity(0.12), lineWidth: 1)
      )
  }

  @ViewBuilder private var thumbnail: some View {
    if let image = thumbnailImage(named: name) {
      platformImage(image)
        .resizable()
        .scaledToFill()
    } else {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(.secondary.opacity(0.18))
        .overlay {
          Image(systemName: "sparkles")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
        }
    }
  }
}

private struct ShaderDetailView: View {
  let entry: ShaderCatalogEntry
  @Binding var selectedPreset: Int
  @Binding var uniforms: [UniformValue]
  @Binding var sizing: ShaderSizingParams
  @Binding var speed: Double
  @Binding var frame: Double
  @Binding var renderOptions: ShaderRenderOptions
  @Binding var renderMetrics: ShaderRenderMetrics
  @State private var showsControls = false
  @State private var showsFullscreen = false
  @State private var showsFPSHUD = true
  @State private var activeSliderID: String?
  #if os(iOS)
  @Environment(\.horizontalSizeClass) private var horizontalSizeClass
  #endif

  private var isCompact: Bool {
    #if os(iOS)
    horizontalSizeClass == .compact
    #else
    false
    #endif
  }

  var body: some View {
    Group {
      if isCompact {
        compactBody
      } else {
        regularBody
      }
    }
    .navigationTitle(entry.descriptor.name)
    #if os(iOS)
    .navigationBarTitleDisplayMode(.inline)
    #endif
    .toolbar {
      ToolbarItem(placement: .secondaryAction) {
        Button {
          showsFullscreen = true
        } label: {
          Image(systemName: "arrow.up.left.and.arrow.down.right")
        }
        .accessibilityLabel("Show fullscreen")
      }
      ToolbarItem(placement: .primaryAction) {
        if isCompact {
          Button {
            withAnimation(.snappy(duration: 0.22)) {
              showsControls.toggle()
            }
          } label: {
            Image(systemName: showsControls ? "xmark" : "slider.horizontal.3")
          }
          .accessibilityLabel(showsControls ? "Hide controls" : "Show controls")
        } else {
          presetPicker
        }
      }
    }
    #if os(iOS)
    .fullScreenCover(isPresented: $showsFullscreen) {
      fullscreenView
    }
    #else
    .overlay {
      if showsFullscreen {
        fullscreenView
      }
    }
    #endif
  }

  private var fullscreenView: some View {
    ShaderFullscreenView(
      entry: entry,
      uniforms: uniforms,
      sizing: sizing,
      speed: speed,
      frame: frame,
      renderOptions: renderOptions,
      renderMetrics: renderMetrics,
      showsFPSHUD: showsFPSHUD,
      onRenderMetricsChanged: { renderMetrics = $0 },
      onDismiss: { showsFullscreen = false }
    )
  }

  private var regularBody: some View {
    HStack(spacing: 0) {
      ShaderPreview(
        entry: entry,
        uniforms: uniforms,
        sizing: sizing,
        speed: speed,
        frame: frame,
        renderOptions: renderOptions,
        renderMetrics: renderMetrics,
        onRenderMetricsChanged: { renderMetrics = $0 },
        onFullscreenPressed: { showsFullscreen = true },
        showsFPSHUD: showsFPSHUD,
        showsCaption: true
      )
      ControlPanel(
        entry: entry,
        selectedPreset: $selectedPreset,
        uniforms: $uniforms,
        sizing: $sizing,
        speed: $speed,
        frame: $frame,
        renderOptions: $renderOptions,
        renderMetrics: renderMetrics,
        showsFPSHUD: $showsFPSHUD,
        activeSliderID: $activeSliderID,
        presentation: .sidebar
      )
      .frame(minWidth: 300, idealWidth: 360, maxWidth: 420)
    }
  }

  private var compactBody: some View {
    ZStack(alignment: .bottom) {
      ShaderPreview(
        entry: entry,
        uniforms: uniforms,
        sizing: sizing,
        speed: speed,
        frame: frame,
        renderOptions: renderOptions,
        renderMetrics: renderMetrics,
        onRenderMetricsChanged: { renderMetrics = $0 },
        onFullscreenPressed: { showsFullscreen = true },
        showsFPSHUD: showsFPSHUD,
        showsCaption: false
      )

      VStack {
        Spacer()
        HStack {
          Spacer()
          Button {
            withAnimation(.snappy(duration: 0.22)) {
              showsControls.toggle()
            }
          } label: {
            Image(systemName: showsControls ? "xmark" : "slider.horizontal.3")
              .font(.system(size: 18, weight: .semibold))
              .frame(width: 48, height: 48)
          }
          .foregroundStyle(.primary)
          .background(.thinMaterial, in: Circle())
          .accessibilityLabel(showsControls ? "Hide controls" : "Show controls")
        }
        .padding(.trailing, 18)
        .padding(.bottom, showsControls ? 424 : 18)
      }

      if showsControls {
        VStack(spacing: 10) {
          Capsule()
            .fill(.secondary.opacity(0.55))
            .frame(width: 36, height: 5)
          ControlPanel(
            entry: entry,
            selectedPreset: $selectedPreset,
            uniforms: $uniforms,
            sizing: $sizing,
            speed: $speed,
            frame: $frame,
            renderOptions: $renderOptions,
            renderMetrics: renderMetrics,
            showsFPSHUD: $showsFPSHUD,
            activeSliderID: $activeSliderID,
            presentation: .overlay
          )
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity)
        .frame(height: 410)
        .background {
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial)
            .opacity(activeSliderID == nil ? 1 : 0)
        }
        .background {
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.black.opacity(activeSliderID == nil ? 0.72 : 0))
        }
        .overlay(
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .stroke(.primary.opacity(0.12), lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
        .transition(.move(edge: .bottom).combined(with: .opacity))
      }
    }
  }

  /// Segmented control where it fits (macOS, iPad regular width); menu in
  /// compact width (iPhone, iPad Split View) where 6 segments overflow.
  @ViewBuilder private var presetPicker: some View {
    let picker = Picker("Preset", selection: $selectedPreset) {
      ForEach(Array(entry.presets.enumerated()), id: \.offset) { index, preset in
        Text(preset.name).tag(index)
      }
    }
    #if os(iOS)
    if horizontalSizeClass == .compact {
      picker.pickerStyle(.menu)
    } else {
      picker.pickerStyle(.segmented)
    }
    #else
    picker.pickerStyle(.segmented)
    #endif
  }
}

private struct ShaderPreview: View {
  let entry: ShaderCatalogEntry
  let uniforms: [UniformValue]
  let sizing: ShaderSizingParams
  let speed: Double
  let frame: Double
  let renderOptions: ShaderRenderOptions
  let renderMetrics: ShaderRenderMetrics
  let onRenderMetricsChanged: (ShaderRenderMetrics) -> Void
  var onFullscreenPressed: (() -> Void)? = nil
  let showsFPSHUD: Bool
  let showsCaption: Bool

  var body: some View {
    ShaderView(
      descriptor: entry.descriptor,
      uniforms: uniforms,
      sizing: sizing,
      speed: speed,
      frame: frame,
      renderOptions: renderOptions,
      onRenderMetricsChanged: onRenderMetricsChanged
    )
    // The representable can't swap pipelines, so rebuild the mount per shader.
    .id(entry.descriptor.name)
    .ignoresSafeArea()
    .overlay(alignment: .topLeading) {
      if showsFPSHUD {
        RenderMetricsHUD(metrics: renderMetrics)
        .padding(18)
      }
    }
    .overlay(alignment: .topTrailing) {
      if let onFullscreenPressed {
        Button(action: onFullscreenPressed) {
          Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.system(size: 16, weight: .semibold))
            .frame(width: 44, height: 44)
        }
        .foregroundStyle(.white)
        .background(.black.opacity(0.42), in: Circle())
        .padding(18)
        .accessibilityLabel("Show fullscreen")
      }
    }
    .overlay(alignment: .bottomLeading) {
      if showsCaption {
        VStack(alignment: .leading, spacing: 4) {
          Text(entry.descriptor.name)
            .font(.title2.bold())
          Text("\(entry.presets.count) presets")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding(18)
      }
    }
  }
}

private struct ShaderFullscreenView: View {
  let entry: ShaderCatalogEntry
  let uniforms: [UniformValue]
  let sizing: ShaderSizingParams
  let speed: Double
  let frame: Double
  let renderOptions: ShaderRenderOptions
  let renderMetrics: ShaderRenderMetrics
  let showsFPSHUD: Bool
  let onRenderMetricsChanged: (ShaderRenderMetrics) -> Void
  let onDismiss: () -> Void

  var body: some View {
    GeometryReader { proxy in
      let overlayPadding = fullscreenOverlayPadding(for: proxy.safeAreaInsets)

      ShaderPreview(
        entry: entry,
        uniforms: uniforms,
        sizing: sizing,
        speed: speed,
        frame: frame,
        renderOptions: renderOptions,
        renderMetrics: renderMetrics,
        onRenderMetricsChanged: onRenderMetricsChanged,
        showsFPSHUD: false,
        showsCaption: false
      )
      .overlay(alignment: .topTrailing) {
        Button(action: onDismiss) {
          Image(systemName: "xmark")
            .font(.system(size: 18, weight: .semibold))
            .frame(width: 46, height: 46)
        }
        .foregroundStyle(.white)
        .background(.black.opacity(0.42), in: Circle())
        .padding(.top, overlayPadding.top)
        .padding(.trailing, overlayPadding.trailing)
        .accessibilityLabel("Exit fullscreen")
      }
      .overlay(alignment: .bottomTrailing) {
        if showsFPSHUD {
          RenderMetricsHUD(metrics: renderMetrics)
            .padding(.trailing, overlayPadding.trailing)
            .padding(.bottom, overlayPadding.bottom)
        }
      }
    }
    .background(Color.black)
  }

  private func fullscreenOverlayPadding(for safeAreaInsets: EdgeInsets) -> EdgeInsets {
    #if os(macOS)
    EdgeInsets(
      top: max(safeAreaInsets.top + 18, 72),
      leading: safeAreaInsets.leading + 18,
      bottom: max(safeAreaInsets.bottom + 18, 18),
      trailing: max(safeAreaInsets.trailing + 18, 18)
    )
    #else
    EdgeInsets(
      top: safeAreaInsets.top + 18,
      leading: safeAreaInsets.leading + 18,
      bottom: safeAreaInsets.bottom + 18,
      trailing: safeAreaInsets.trailing + 18
    )
    #endif
  }
}

private struct RenderMetricsHUD: View {
  let metrics: ShaderRenderMetrics

  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      metricLine("FPS", formatted(metrics.framesPerSecond, digits: 0))
      metricLine("Drawable", "\(metrics.drawablePixelWidth)x\(metrics.drawablePixelHeight)")
      metricLine("Scale", formatted(metrics.renderScale, digits: 2))
      metricLine("DPR", formatted(metrics.displayScale, digits: 2))
      metricLine("Pixels", "\(formatted(pixelCountMegapixels, digits: 1)) MP")
      metricLine("Math", metrics.mathMode.rawValue)
      if metrics.adaptiveResolutionScale < 0.999 {
        metricLine("Adaptive", formatted(metrics.adaptiveResolutionScale, digits: 2))
      }
    }
    .font(.system(.caption2, design: .monospaced))
    .foregroundStyle(.white)
    .frame(width: 190, alignment: .leading)
    .padding(.vertical, 8)
    .padding(.horizontal, 10)
    .background(.black.opacity(0.54), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(.white.opacity(0.16), lineWidth: 1)
    )
    .allowsHitTesting(false)
  }

  private var pixelCountMegapixels: Double {
    Double(metrics.drawablePixelWidth * metrics.drawablePixelHeight) / 1_000_000
  }

  private func metricLine(_ label: String, _ value: String) -> some View {
    HStack(spacing: 8) {
      Text(label)
        .foregroundStyle(.white.opacity(0.68))
      Spacer(minLength: 12)
      Text(value)
        .fontWeight(.semibold)
    }
  }
}

private struct RenderMetricsList: View {
  let metrics: ShaderRenderMetrics

  var body: some View {
    Group {
      LabeledContent("FPS", value: formatted(metrics.framesPerSecond, digits: 0))
      LabeledContent("Frame", value: "\(formatted(metrics.frameDurationMilliseconds, digits: 1)) ms")
      LabeledContent("Drawable", value: "\(metrics.drawablePixelWidth)x\(metrics.drawablePixelHeight)")
      LabeledContent("Render Scale", value: formatted(metrics.renderScale, digits: 2))
      LabeledContent("Display Scale", value: formatted(metrics.displayScale, digits: 2))
      LabeledContent("Math", value: metrics.mathMode.rawValue)
      LabeledContent("Pixels", value: "\(formatted(pixelCountMegapixels, digits: 1)) MP")
      LabeledContent("Adaptive Scale", value: formatted(metrics.adaptiveResolutionScale, digits: 2))
    }
    .font(.caption.monospacedDigit())
    .foregroundStyle(.secondary)
  }

  private var pixelCountMegapixels: Double {
    Double(metrics.drawablePixelWidth * metrics.drawablePixelHeight) / 1_000_000
  }
}

private enum ControlPanelPresentation {
  case sidebar
  case overlay
}

private struct ControlPanel: View {
  let entry: ShaderCatalogEntry
  @Binding var selectedPreset: Int
  @Binding var uniforms: [UniformValue]
  @Binding var sizing: ShaderSizingParams
  @Binding var speed: Double
  @Binding var frame: Double
  @Binding var renderOptions: ShaderRenderOptions
  let renderMetrics: ShaderRenderMetrics
  @Binding var showsFPSHUD: Bool
  @Binding var activeSliderID: String?
  let presentation: ControlPanelPresentation
  @State private var showsAdvancedRender = false

  var body: some View {
    switch presentation {
    case .sidebar:
      Form {
        Section("Preset") {
          focusedControl {
            presetPicker
          }
        }

        Section("Motion") {
          motionControls
        }

        Section("Sizing") {
          sizingControls
        }

        Section("Shader") {
          shaderControls
        }

        Section("Render") {
          renderControls
        }

        Section("Code") {
          focusedControl {
            CodeSnippetView(
              title: "Swift preset",
              snippet: swiftInitializationSnippet(
                entry: entry,
                uniforms: uniforms,
                sizing: sizing,
                speed: speed,
                frame: frame
              )
            )
          }
        }
      }
      .formStyle(.grouped)
    case .overlay:
      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          CompactControlSection(title: "Preset", activeSliderID: activeSliderID) {
            focusedControl {
              presetPicker
            }
          }
          CompactControlSection(title: "Motion", activeSliderID: activeSliderID) {
            motionControls
          }
          CompactControlSection(title: "Sizing", activeSliderID: activeSliderID) {
            sizingControls
          }
          CompactControlSection(title: "Shader", activeSliderID: activeSliderID) {
            shaderControls
          }
          CompactControlSection(title: "Render", activeSliderID: activeSliderID) {
            renderControls
          }
          CompactControlSection(title: "Code", activeSliderID: activeSliderID) {
            focusedControl {
              CodeSnippetView(
                title: "Swift preset",
                snippet: swiftInitializationSnippet(
                  entry: entry,
                  uniforms: uniforms,
                  sizing: sizing,
                  speed: speed,
                  frame: frame
                )
              )
            }
          }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 24)
      }
    }
  }

  private var presetPicker: some View {
    Picker("Preset", selection: $selectedPreset) {
      ForEach(Array(entry.presets.enumerated()), id: \.offset) { index, preset in
        Text(preset.name).tag(index)
      }
    }
  }

  @ViewBuilder private var motionControls: some View {
    focusedControl(id: "motion.speed") {
      NumericSlider(
        label: "Speed",
        value: $speed,
        range: 0...4,
        step: 0.05,
        sliderID: "motion.speed",
        activeSliderID: $activeSliderID
      )
    }
    focusedControl(id: "motion.frame") {
      NumericSlider(
        label: "Frame",
        value: $frame,
        range: 0...120_000,
        step: 500,
        sliderID: "motion.frame",
        activeSliderID: $activeSliderID
      )
    }
  }

  @ViewBuilder private var sizingControls: some View {
    focusedControl {
      Picker("Fit", selection: $sizing.fit) {
        Text("None").tag(ShaderFit.none)
        Text("Contain").tag(ShaderFit.contain)
        Text("Cover").tag(ShaderFit.cover)
      }
    }
    focusedControl(id: "sizing.scale") {
      NumericFloatSlider(
        label: "Scale",
        value: $sizing.scale,
        range: 0.05...5,
        sliderID: "sizing.scale",
        activeSliderID: $activeSliderID
      )
    }
    focusedControl(id: "sizing.rotation") {
      NumericFloatSlider(
        label: "Rotation",
        value: $sizing.rotation,
        range: -360...360,
        sliderID: "sizing.rotation",
        activeSliderID: $activeSliderID
      )
    }
    focusedControl(id: "sizing.offsetX") {
      NumericFloatSlider(
        label: "Offset X",
        value: $sizing.offsetX,
        range: -1...1,
        sliderID: "sizing.offsetX",
        activeSliderID: $activeSliderID
      )
    }
    focusedControl(id: "sizing.offsetY") {
      NumericFloatSlider(
        label: "Offset Y",
        value: $sizing.offsetY,
        range: -1...1,
        sliderID: "sizing.offsetY",
        activeSliderID: $activeSliderID
      )
    }
    focusedControl(id: "sizing.originX") {
      NumericFloatSlider(
        label: "Origin X",
        value: $sizing.originX,
        range: 0...1,
        sliderID: "sizing.originX",
        activeSliderID: $activeSliderID
      )
    }
    focusedControl(id: "sizing.originY") {
      NumericFloatSlider(
        label: "Origin Y",
        value: $sizing.originY,
        range: 0...1,
        sliderID: "sizing.originY",
        activeSliderID: $activeSliderID
      )
    }
  }

  @ViewBuilder private var renderControls: some View {
    focusedControl {
      Toggle("Adaptive 60 FPS", isOn: adaptiveQualityEnabled)
    }
    focusedControl {
      Toggle("Show FPS HUD", isOn: $showsFPSHUD)
    }

    DisclosureGroup("Advanced Render", isExpanded: $showsAdvancedRender) {
      VStack(alignment: .leading, spacing: 12) {
        advancedRenderControls
      }
      .padding(.top, 8)
    }
  }

  @ViewBuilder private var advancedRenderControls: some View {
    focusedControl {
      Toggle("Precise Math", isOn: preciseMathEnabled)
    }
    focusedControl(id: "render.minPixelRatio") {
      NumericSlider(
        label: "Min Pixel Ratio",
        value: $renderOptions.minPixelRatio,
        range: 1...3,
        step: 0.25,
        sliderID: "render.minPixelRatio",
        activeSliderID: $activeSliderID
      )
    }
    focusedControl(id: "render.maxPixelCount") {
      NumericSlider(
        label: "Max Pixel Count",
        value: maxPixelCountMegapixels,
        range: 0.5...12,
        step: 0.1,
        sliderID: "render.maxPixelCount",
        activeSliderID: $activeSliderID
      )
    }
    if renderOptions.adaptiveTargetFrameRate != nil {
      focusedControl(id: "render.adaptiveMinimumPixelRatio") {
        NumericSlider(
          label: "Adaptive Min Ratio",
          value: $renderOptions.adaptiveMinimumPixelRatio,
          range: 0.5...3,
          step: 0.25,
          sliderID: "render.adaptiveMinimumPixelRatio",
          activeSliderID: $activeSliderID
        )
      }
    }
    focusedControl {
      renderMetricsView
    }
  }

  private var maxPixelCountMegapixels: Binding<Double> {
    Binding(
      get: { renderOptions.maxPixelCount / 1_000_000 },
      set: { renderOptions.maxPixelCount = $0 * 1_000_000 }
    )
  }

  private var adaptiveQualityEnabled: Binding<Bool> {
    Binding(
      get: { renderOptions.adaptiveTargetFrameRate != nil },
      set: { enabled in
        renderOptions.adaptiveTargetFrameRate = enabled ? 60 : nil
      }
    )
  }

  private var preciseMathEnabled: Binding<Bool> {
    Binding(
      get: { renderOptions.mathMode == .precise },
      set: { enabled in
        renderOptions.mathMode = enabled ? .precise : .fast
      }
    )
  }

  private var renderMetricsView: some View {
    RenderMetricsList(metrics: renderMetrics)
  }

  @ViewBuilder private var shaderControls: some View {
    let names = entry.uniformMemberNames
    ForEach(Array(zip(names.indices, names)), id: \.0) { index, name in
      if index < uniforms.count {
        UniformControl(
          name: name,
          index: index,
          value: $uniforms[index],
          presets: entry.presets,
          activeSliderID: $activeSliderID,
          dimsControlsOnSliderDrag: presentation == .overlay
        )
      }
    }
  }

  private func focusedControl<Content: View>(
    id: String? = nil,
    @ViewBuilder content: () -> Content
  ) -> some View {
    SliderFocusContainer(
      activeSliderID: presentation == .overlay ? activeSliderID : nil,
      controlID: id,
      content: content()
    )
  }
}

private struct SliderFocusContainer<Content: View>: View {
  let activeSliderID: String?
  let controlID: String?
  let content: Content

  private var isFocused: Bool {
    activeSliderID == nil || activeSliderID == controlID
  }

  var body: some View {
    content
      .opacity(isFocused ? 1 : 0.08)
      .allowsHitTesting(isFocused)
      .animation(.easeOut(duration: 0.14), value: activeSliderID)
  }
}

private struct CompactControlSection<Content: View>: View {
  let title: String
  let activeSliderID: String?
  @ViewBuilder let content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text(title.uppercased())
        .font(.caption.weight(.bold))
        .foregroundStyle(.secondary)
      VStack(alignment: .leading, spacing: 0) {
        content
      }
      .padding(12)
      .background(
        .black.opacity(activeSliderID == nil ? 0.24 : 0),
        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
      )
    }
  }
}

private struct CodeSnippetView: View {
  let title: String
  let snippet: String
  @State private var didCopy = false

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack {
        Text(title)
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Spacer()
        Button {
          copyToClipboard(snippet)
          didCopy = true
        } label: {
          Label(didCopy ? "Copied" : "Copy", systemImage: didCopy ? "checkmark" : "doc.on.doc")
        }
        .buttonStyle(.bordered)
      }

      ScrollView(.horizontal) {
        Text(snippet)
          .font(.system(.caption, design: .monospaced))
          .textSelection(.enabled)
          .padding(10)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .background(.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    .onChange(of: snippet) { _ in
      didCopy = false
    }
  }
}

private struct UniformControl: View {
  let name: String
  let index: Int
  @Binding var value: UniformValue
  let presets: [ShaderCatalogEntry.Preset]
  @Binding var activeSliderID: String?
  let dimsControlsOnSliderDrag: Bool

  var body: some View {
    switch value {
    case .float(let current):
      if isToggleUniform(name) {
        focusedControl {
          Toggle(displayName(name), isOn: toggleBinding)
        }
      } else {
        let sliderID = "uniform.\(index)"
        focusedControl(id: sliderID) {
          NumericFloatSlider(
            label: displayName(name),
            value: floatBinding(current),
            range: floatRange(current),
            step: floatStep(current),
            sliderID: sliderID,
            activeSliderID: $activeSliderID
          )
        }
      }
    case .float2(let current):
      let xSliderID = "uniform.\(index).x"
      focusedControl(id: xSliderID) {
        NumericFloatSlider(
          label: "\(displayName(name)) X",
          value: float2Binding(component: 0, current: current),
          range: -2...2,
          step: 0.025,
          sliderID: xSliderID,
          activeSliderID: $activeSliderID
        )
      }
      let ySliderID = "uniform.\(index).y"
      focusedControl(id: ySliderID) {
        NumericFloatSlider(
          label: "\(displayName(name)) Y",
          value: float2Binding(component: 1, current: current),
          range: -2...2,
          step: 0.025,
          sliderID: ySliderID,
          activeSliderID: $activeSliderID
        )
      }
    case .float4(let current):
      focusedControl {
        ColorControl(label: displayName(name), color: colorBinding(current))
      }
    case .float4Array(let values, let capacity):
      ForEach(values.indices, id: \.self) { colorIndex in
        focusedControl {
          ColorControl(
            label: "\(displayName(name)) \(colorIndex + 1)",
            color: colorArrayBinding(values: values, capacity: capacity, index: colorIndex)
          )
        }
      }
    }
  }

  private func focusedControl<Content: View>(
    id: String? = nil,
    @ViewBuilder content: () -> Content
  ) -> some View {
    SliderFocusContainer(
      activeSliderID: dimsControlsOnSliderDrag ? activeSliderID : nil,
      controlID: id,
      content: content()
    )
  }

  private var toggleBinding: Binding<Bool> {
    Binding(
      get: {
        if case .float(let current) = value {
          return current >= 0.5
        }
        return false
      },
      set: { enabled in
        value = .float(enabled ? 1 : 0)
      }
    )
  }

  private func floatBinding(_ current: Float) -> Binding<Float> {
    Binding(
      get: {
        if case .float(let current) = value { return current }
        return current
      },
      set: { next in
        value = .float(next)
      }
    )
  }

  private func float2Binding(component: Int, current: SIMD2<Float>) -> Binding<Float> {
    Binding(
      get: {
        if case .float2(let current) = value {
          return component == 0 ? current.x : current.y
        }
        return component == 0 ? current.x : current.y
      },
      set: { next in
        var updated = current
        if case .float2(let current) = value {
          updated = current
        }
        if component == 0 {
          updated.x = next
        } else {
          updated.y = next
        }
        value = .float2(updated)
      }
    )
  }

  private func colorBinding(_ current: SIMD4<Float>) -> Binding<Color> {
    Binding(
      get: {
        if case .float4(let current) = value {
          return Color(premultiplied: current)
        }
        return Color(premultiplied: current)
      },
      set: { next in
        value = .float4(next.premultipliedSIMD4)
      }
    )
  }

  private func colorArrayBinding(values: [SIMD4<Float>], capacity: Int, index: Int) -> Binding<Color> {
    Binding(
      get: {
        if case .float4Array(let values, _) = value, index < values.count {
          return Color(premultiplied: values[index])
        }
        return Color(premultiplied: values[index])
      },
      set: { next in
        var updated = values
        if case .float4Array(let values, _) = value {
          updated = values
        }
        guard index < updated.count else { return }
        updated[index] = next.premultipliedSIMD4
        value = .float4Array(updated, capacity: capacity)
      }
    )
  }

  private func floatRange(_ current: Float) -> ClosedRange<Float> {
    if name == "u_colorsCount" {
      return 1...10
    }
    if name.localizedCaseInsensitiveContains("angle") {
      return -360...360
    }
    if name.localizedCaseInsensitiveContains("gap") {
      return 0...96
    }

    let presetValues = presets.compactMap { preset -> Float? in
      guard index < preset.uniforms.count, case .float(let value) = preset.uniforms[index] else {
        return nil
      }
      return value
    }
    let values = presetValues + [current]
    guard var minValue = values.min(), var maxValue = values.max() else {
      return 0...1
    }
    if minValue >= 0, maxValue <= 1 {
      return 0...1
    }
    if minValue == maxValue {
      let padding = max(abs(minValue) * 0.5, 1)
      minValue -= padding
      maxValue += padding
      if minValue >= 0 {
        minValue = 0
      }
    } else {
      let padding = max((maxValue - minValue) * 0.25, 0.5)
      minValue -= padding
      maxValue += padding
      if minValue > 0, current >= 0 {
        minValue = 0
      }
    }
    return minValue...maxValue
  }

  private func floatStep(_ current: Float) -> Float {
    let range = floatRange(current)
    let span = range.upperBound - range.lowerBound
    if span <= 1 { return 0.01 }
    if span <= 12 { return 0.1 }
    return 1
  }
}

private struct NumericSlider: View {
  let label: String
  @Binding var value: Double
  let range: ClosedRange<Double>
  let step: Double
  let sliderID: String
  @Binding var activeSliderID: String?

  var body: some View {
    LabeledContent {
      VStack(alignment: .trailing, spacing: 4) {
        Text(value.formatted(.number.precision(.fractionLength(value.magnitude >= 100 ? 0 : 2))))
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
        TouchAwareSlider(value: $value, range: range, step: step) { editing in
          if editing {
            markActive()
          } else {
            clearActive()
          }
        }
          .frame(minWidth: 120)
          .onDisappear {
            clearActive()
          }
      }
    } label: {
      Text(label)
    }
  }

  private func markActive() {
    activeSliderID = sliderID
  }

  private func clearActive() {
    if activeSliderID == sliderID {
      activeSliderID = nil
    }
  }
}

private struct NumericFloatSlider: View {
  let label: String
  @Binding var value: Float
  let range: ClosedRange<Float>
  var step: Float? = nil
  let sliderID: String
  @Binding var activeSliderID: String?

  private var doubleValue: Binding<Double> {
    Binding(
      get: { Double(value) },
      set: { value = Float($0) }
    )
  }

  var body: some View {
    LabeledContent {
      VStack(alignment: .trailing, spacing: 4) {
        Text(Double(value).formatted(.number.precision(.fractionLength(abs(value) >= 100 ? 0 : 2))))
          .font(.caption.monospacedDigit())
          .foregroundStyle(.secondary)
        TouchAwareSlider(
          value: doubleValue,
          range: Double(range.lowerBound)...Double(range.upperBound),
          step: step.map(Double.init)
        ) { editing in
          if editing {
            markActive()
          } else {
            clearActive()
          }
        }
          .frame(minWidth: 120)
          .onDisappear {
            clearActive()
          }
      }
    } label: {
      Text(label)
    }
  }

  private func markActive() {
    activeSliderID = sliderID
  }

  private func clearActive() {
    if activeSliderID == sliderID {
      activeSliderID = nil
    }
  }
}

private struct TouchAwareSlider: View {
  @Binding var value: Double
  let range: ClosedRange<Double>
  var step: Double?
  let onEditingChanged: (Bool) -> Void

  var body: some View {
    #if os(iOS)
    UIKitTouchAwareSlider(
      value: $value,
      range: range,
      step: step,
      onEditingChanged: onEditingChanged
    )
    #else
    if let step {
      Slider(value: $value, in: range, step: step, onEditingChanged: onEditingChanged)
    } else {
      Slider(value: $value, in: range, onEditingChanged: onEditingChanged)
    }
    #endif
  }
}

#if os(iOS)
private struct UIKitTouchAwareSlider: UIViewRepresentable {
  @Binding var value: Double
  let range: ClosedRange<Double>
  var step: Double?
  let onEditingChanged: (Bool) -> Void

  func makeUIView(context: Context) -> UISlider {
    let slider = UISlider(frame: .zero)
    slider.minimumValue = Float(range.lowerBound)
    slider.maximumValue = Float(range.upperBound)
    slider.isContinuous = true
    slider.addTarget(context.coordinator, action: #selector(Coordinator.touchDown), for: .touchDown)
    slider.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
    slider.addTarget(
      context.coordinator,
      action: #selector(Coordinator.touchEnded),
      for: [.touchUpInside, .touchUpOutside, .touchCancel]
    )
    return slider
  }

  func updateUIView(_ slider: UISlider, context: Context) {
    slider.minimumValue = Float(range.lowerBound)
    slider.maximumValue = Float(range.upperBound)
    slider.isEnabled = true
    let next = Float(clamped(value))
    if abs(slider.value - next) > 0.0001 {
      slider.value = next
    }
    context.coordinator.parent = self
  }

  func makeCoordinator() -> Coordinator {
    Coordinator(parent: self)
  }

  private func stepped(_ rawValue: Double) -> Double {
    guard let step, step > 0 else {
      return clamped(rawValue)
    }
    let steps = ((rawValue - range.lowerBound) / step).rounded()
    return clamped(range.lowerBound + steps * step)
  }

  private func clamped(_ rawValue: Double) -> Double {
    min(max(rawValue, range.lowerBound), range.upperBound)
  }

  final class Coordinator: NSObject {
    var parent: UIKitTouchAwareSlider

    init(parent: UIKitTouchAwareSlider) {
      self.parent = parent
    }

    @objc func touchDown() {
      parent.onEditingChanged(true)
    }

    @objc func valueChanged(_ slider: UISlider) {
      parent.value = parent.stepped(Double(slider.value))
    }

    @objc func touchEnded() {
      parent.onEditingChanged(false)
    }
  }
}
#endif

private struct ColorControl: View {
  let label: String
  @Binding var color: Color

  var body: some View {
    LabeledContent {
      ColorPicker("", selection: $color, supportsOpacity: true)
        .labelsHidden()
    } label: {
      Text(label)
    }
  }
}

private func isToggleUniform(_ name: String) -> Bool {
  name == "u_isImage" || name == "u_originalColors" || name == "u_inverted"
}

private func displayName(_ name: String) -> String {
  let raw = name.hasPrefix("u_") ? String(name.dropFirst(2)) : name
  var output = ""
  for scalar in raw.unicodeScalars {
    let character = Character(scalar)
    if scalar == "_" {
      output.append(" ")
    } else if CharacterSet.uppercaseLetters.contains(scalar), !output.isEmpty {
      output.append(" ")
      output.append(character)
    } else {
      output.append(character)
    }
  }
  return output
    .split(separator: " ")
    .map { word in word.prefix(1).uppercased() + word.dropFirst() }
    .joined(separator: " ")
}

private func formatted(_ value: Double, digits: Int) -> String {
  value.formatted(.number.precision(.fractionLength(digits)))
}

private func swiftInitializationSnippet(
  entry: ShaderCatalogEntry,
  uniforms: [UniformValue],
  sizing: ShaderSizingParams,
  speed: Double,
  frame: Double
) -> String {
  if let typedSnippet = swiftTypedInitializationSnippet(
    entry: entry,
    uniforms: uniforms,
    sizing: sizing,
    speed: speed,
    frame: frame
  ) {
    return typedSnippet
  }

  let shaderType = swiftShaderTypeName(entry.descriptor.name)
  let uniformLines = zip(entry.uniformMemberNames, uniforms).map { name, value in
    "    \(swiftUniformLiteral(value)), // \(name)"
  }
  let uniformsBody = uniformLines.isEmpty ? "" : "\n\(uniformLines.joined(separator: "\n"))\n  "

  return """
  let customPreset = ShaderCatalogEntry.Preset(
    name: "Custom \(entry.descriptor.name)",
    sizing: \(swiftSizingLiteral(sizing)),
    uniforms: [\(uniformsBody)],
    speed: \(formatNumber(speed))
  )

  ShaderView(
    descriptor: \(shaderType).descriptor,
    uniforms: customPreset.uniforms,
    sizing: customPreset.sizing,
    speed: customPreset.speed,
    frame: \(formatNumber(frame))
  )
  """
}

private func swiftTypedInitializationSnippet(
  entry: ShaderCatalogEntry,
  uniforms: [UniformValue],
  sizing: ShaderSizingParams,
  speed: Double,
  frame: Double
) -> String? {
  let shaderType = swiftShaderTypeName(entry.descriptor.name)
  var arguments: [String] = []

  for (name, value) in zip(entry.uniformMemberNames, uniforms) {
    guard let argument = swiftTypedArgument(name: name, value: value) else {
      return nil
    }
    if !argument.isEmpty {
      arguments.append(argument)
    }
  }

  arguments.append("sizing: \(swiftSizingLiteral(sizing))")
  arguments.append("speed: \(formatNumber(speed))")
  arguments.append("frame: \(formatNumber(frame))")

  let argumentLines = arguments.map { "    \($0)" }.joined(separator: ",\n")
  return """
  \(shaderType)View(
    params: \(shaderType).Params(
  \(argumentLines)
    )
  )
  """
}

private func swiftTypedArgument(name: String, value: UniformValue) -> String? {
  let parameter = swiftParameterName(name)
  if parameter == "colorsCount" {
    return ""
  }
  if swiftEnumBackedParameters.contains(parameter) {
    return nil
  }

  switch value {
  case .float(let value):
    return "\(parameter): \(formatNumber(value))"
  case .float4(let value):
    return "\(parameter): \"\(hexColor(fromPremultiplied: value))\""
  case .float4Array(let values, _):
    guard parameter == "colors" else { return nil }
    let colors = values.map { "\"\(hexColor(fromPremultiplied: $0))\"" }.joined(separator: ", ")
    return "colors: [\(colors)]"
  case .float2:
    return nil
  }
}

private let swiftEnumBackedParameters: Set<String> = [
  "aspectRatio",
  "ditherType",
  "distortionShape",
  "dotType",
  "grid",
  "shape",
  "strokeCap",
  "type",
]

private func swiftParameterName(_ uniformName: String) -> String {
  let raw = uniformName.hasPrefix("u_") ? String(uniformName.dropFirst(2)) : uniformName
  guard let first = raw.first else { return raw }
  return first.lowercased() + raw.dropFirst()
}

private func swiftShaderTypeName(_ name: String) -> String {
  name
    .split(separator: "-")
    .map { part in part.prefix(1).uppercased() + part.dropFirst() }
    .joined()
}

private func swiftSizingLiteral(_ sizing: ShaderSizingParams) -> String {
  """
  ShaderSizingParams(
      fit: .\(sizing.fit.rawValue),
      scale: \(formatNumber(sizing.scale)),
      rotation: \(formatNumber(sizing.rotation)),
      originX: \(formatNumber(sizing.originX)),
      originY: \(formatNumber(sizing.originY)),
      offsetX: \(formatNumber(sizing.offsetX)),
      offsetY: \(formatNumber(sizing.offsetY)),
      worldWidth: \(formatNumber(sizing.worldWidth)),
      worldHeight: \(formatNumber(sizing.worldHeight))
    )
  """
}

private func swiftUniformLiteral(_ value: UniformValue) -> String {
  switch value {
  case .float(let value):
    return ".float(\(formatNumber(value)))"
  case .float2(let value):
    return ".float2(SIMD2<Float>(\(formatNumber(value.x)), \(formatNumber(value.y))))"
  case .float4(let value):
    return ".float4(ShaderColor.parse(\"\(hexColor(fromPremultiplied: value))\"))"
  case .float4Array(let values, let capacity):
    let items = values
      .map { "      \"\(hexColor(fromPremultiplied: $0))\"" }
      .joined(separator: ",\n")
    return ".float4Array([\n\(items)\n    ].map(ShaderColor.parse), capacity: \(capacity))"
  }
}

private func formatNumber(_ value: Float) -> String {
  formatNumber(Double(value))
}

private func formatNumber(_ value: Double) -> String {
  if value == 0 { return "0" }
  if value.rounded() == value, abs(value) < 1_000_000 {
    return String(Int(value))
  }
  return String(format: "%.6g", locale: Locale(identifier: "en_US_POSIX"), value)
}

private func hexColor(fromPremultiplied value: SIMD4<Float>) -> String {
  let alpha = max(0, min(1, Double(value.w)))
  let red = alpha == 0 ? 0 : max(0, min(1, Double(value.x) / alpha))
  let green = alpha == 0 ? 0 : max(0, min(1, Double(value.y) / alpha))
  let blue = alpha == 0 ? 0 : max(0, min(1, Double(value.z) / alpha))
  let components = [
    Int((red * 255).rounded()),
    Int((green * 255).rounded()),
    Int((blue * 255).rounded()),
  ]
  if alpha >= 0.999 {
    return String(format: "#%02X%02X%02X", components[0], components[1], components[2])
  }
  return String(
    format: "#%02X%02X%02X%02X",
    components[0],
    components[1],
    components[2],
    Int((alpha * 255).rounded())
  )
}

private func copyToClipboard(_ text: String) {
  #if os(macOS)
  NSPasteboard.general.clearContents()
  NSPasteboard.general.setString(text, forType: .string)
  #elseif os(iOS)
  UIPasteboard.general.string = text
  #endif
}

#if os(macOS)
private typealias PlatformImage = NSImage
#elseif os(iOS)
private typealias PlatformImage = UIImage
#endif

private func thumbnailImage(named name: String) -> PlatformImage? {
  guard let url = thumbnailBundle.url(
    forResource: name,
    withExtension: "png",
    subdirectory: "Thumbnails"
  ) ?? thumbnailBundle.url(forResource: name, withExtension: "png") else {
    return nil
  }
  return PlatformImage(contentsOfFile: url.path)
}

private var thumbnailBundle: Bundle {
  #if SWIFT_PACKAGE
  Bundle.module
  #else
  Bundle.main
  #endif
}

private func platformImage(_ image: PlatformImage) -> Image {
  #if os(macOS)
  Image(nsImage: image)
  #elseif os(iOS)
  Image(uiImage: image)
  #endif
}

private extension Color {
  init(premultiplied value: SIMD4<Float>) {
    let alpha = max(0, min(1, Double(value.w)))
    let red = alpha == 0 ? 0 : max(0, min(1, Double(value.x) / alpha))
    let green = alpha == 0 ? 0 : max(0, min(1, Double(value.y) / alpha))
    let blue = alpha == 0 ? 0 : max(0, min(1, Double(value.z) / alpha))
    self.init(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
  }

  var premultipliedSIMD4: SIMD4<Float> {
    #if os(macOS)
    let platformColor = NSColor(self)
    let resolved = platformColor.usingColorSpace(.sRGB) ?? platformColor
    #else
    let resolved = UIColor(self)
    #endif
    var red: CGFloat = 0
    var green: CGFloat = 0
    var blue: CGFloat = 0
    var alpha: CGFloat = 0
    resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
    return SIMD4(
      Float(red * alpha),
      Float(green * alpha),
      Float(blue * alpha),
      Float(alpha)
    )
  }
}
