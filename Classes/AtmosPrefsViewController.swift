//
//  AtmosPrefsViewController.swift
//  Subler
//
//  Preferences pane for the external tools used to re-encode TrueHD Atmos
//  tracks to E-AC3 with Joint Object Coding (EAC3-JOC).
//

import Cocoa

final class AtmosPrefsViewController: NSViewController {

    private struct ToolRow {
        let name: String
        let label: String
        let defaultsKey: String
        let field: NSTextField
        let status: NSTextField
    }

    private var rows: [ToolRow] = []

    init() {
        super.init(nibName: nil, bundle: nil)
        self.title = NSLocalizedString("Atmos", comment: "Preferences pane title.")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Built entirely in code so no .xib is required.
    override func loadView() {
        let grid = NSGridView()
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 8
        grid.columnSpacing = 8

        let header = makeLabel(NSLocalizedString("Tools used to convert TrueHD Atmos to EAC3-JOC:", comment: ""),
                               alignment: .left)
        header.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        // Note: cells can only be merged once the grid has its full column count,
        // which happens after the 4-column tool rows are added below.
        let headerRow = grid.addRow(with: [header])

        let toolDefs: [(name: String, label: String, key: String)] = [
            ("deezy", "deezy:", "SBAtmosDeezyPath"),
            ("truehdd", "truehdd:", "SBAtmosTruehddPath"),
            ("dee", "dee (Dolby Encoding Engine):", "SBAtmosDeePath"),
            ("ffmpeg", "ffmpeg:", "SBAtmosFFmpegPath"),
        ]

        for def in toolDefs {
            let label = makeLabel(def.label, alignment: .right)

            let field = NSTextField()
            field.translatesAutoresizingMaskIntoConstraints = false
            field.placeholderString = NSLocalizedString("Auto-detected if left empty", comment: "")
            field.delegate = self
            field.bind(.value,
                       to: NSUserDefaultsController.shared,
                       withKeyPath: "values.\(def.key)",
                       options: [.continuouslyUpdatesValue: true])
            field.widthAnchor.constraint(greaterThanOrEqualToConstant: 320).isActive = true

            let browse = NSButton(title: NSLocalizedString("Browse…", comment: ""),
                                  target: self, action: #selector(browse(_:)))
            browse.bezelStyle = .rounded
            browse.tag = rows.count

            let status = makeLabel("", alignment: .center)
            status.widthAnchor.constraint(equalToConstant: 18).isActive = true

            grid.addRow(with: [label, field, browse, status])
            rows.append(ToolRow(name: def.name, label: def.label, defaultsKey: def.key, field: field, status: status))
        }

        // Bitrate
        let bitrateLabel = makeLabel(NSLocalizedString("Bitrate (kbps):", comment: ""), alignment: .right)
        let bitrateField = NSTextField()
        bitrateField.translatesAutoresizingMaskIntoConstraints = false
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .none
        numberFormatter.minimum = 384
        numberFormatter.maximum = 1664
        bitrateField.formatter = numberFormatter
        bitrateField.bind(.value,
                          to: NSUserDefaultsController.shared,
                          withKeyPath: "values.SBAtmosBitrate",
                          options: [.continuouslyUpdatesValue: true])
        bitrateField.widthAnchor.constraint(equalToConstant: 80).isActive = true
        grid.addRow(with: [bitrateLabel, bitrateField])

        // Atmos mode
        let modeLabel = makeLabel(NSLocalizedString("Mode:", comment: ""), alignment: .right)
        let modePopup = NSPopUpButton()
        modePopup.translatesAutoresizingMaskIntoConstraints = false
        modePopup.addItem(withTitle: "streaming")
        modePopup.lastItem?.representedObject = "streaming"
        modePopup.addItem(withTitle: "bluray")
        modePopup.lastItem?.representedObject = "bluray"
        modePopup.selectItem(withTitle: Prefs.atmosMode)
        modePopup.target = self
        modePopup.action = #selector(setMode(_:))
        grid.addRow(with: [modeLabel, modePopup])

        // Detect button + note
        let detect = NSButton(title: NSLocalizedString("Detect installed tools", comment: ""),
                              target: self, action: #selector(detectTools(_:)))
        detect.bezelStyle = .rounded
        let detectRow = grid.addRow(with: [NSGridCell.emptyContentView, detect])
        detectRow.cell(at: 1).xPlacement = .leading

        let note = makeLabel(NSLocalizedString("dee and ffmpeg are usually auto-detected. deezy and truehdd normally need to be set manually. dee (x86_64) requires Rosetta 2.", comment: ""),
                             alignment: .left)
        note.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        note.textColor = .secondaryLabelColor
        note.lineBreakMode = .byWordWrapping
        note.maximumNumberOfLines = 0
        note.preferredMaxLayoutWidth = 460
        let noteRow = grid.addRow(with: [note])

        // Now that the grid has all 4 columns, span the header and note across them.
        let columns = grid.numberOfColumns
        if columns > 1 {
            headerRow.mergeCells(in: NSRange(location: 0, length: columns))
            noteRow.mergeCells(in: NSRange(location: 0, length: columns))
        }

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 560, height: 320))
        container.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -20),
            grid.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            grid.bottomAnchor.constraint(lessThanOrEqualTo: container.bottomAnchor, constant: -20),
        ])

        self.view = container
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refreshStatuses()
    }

    // MARK: - Helpers

    private func makeLabel(_ string: String, alignment: NSTextAlignment) -> NSTextField {
        let label = NSTextField(labelWithString: string)
        label.alignment = alignment
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    private func refreshStatuses() {
        let fm = FileManager.default
        for row in rows {
            let stored = UserDefaults.standard.string(forKey: row.defaultsKey) ?? ""
            let resolved = AtmosTools.resolved(stored, name: row.name)
            if !resolved.isEmpty && fm.isExecutableFile(atPath: resolved) {
                row.status.stringValue = "✓"
                row.status.textColor = .systemGreen
                row.status.toolTip = resolved
            } else {
                row.status.stringValue = "✗"
                row.status.textColor = .systemRed
                row.status.toolTip = NSLocalizedString("Not found", comment: "")
            }
        }
    }

    // MARK: - Actions

    @objc private func browse(_ sender: NSButton) {
        let index = sender.tag
        guard index >= 0 && index < rows.count else { return }
        let row = rows[index]

        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.title = String(format: NSLocalizedString("Select the %@ executable", comment: ""), row.name)

        panel.beginSheetModal(for: view.window!) { response in
            if response == .OK, let url = panel.url {
                row.field.stringValue = url.path
                UserDefaults.standard.set(url.path, forKey: row.defaultsKey)
                self.refreshStatuses()
            }
        }
    }

    @objc private func detectTools(_ sender: NSButton) {
        for row in rows {
            let stored = UserDefaults.standard.string(forKey: row.defaultsKey) ?? ""
            if stored.isEmpty, let detected = AtmosTools.detect(row.name) {
                row.field.stringValue = detected
                UserDefaults.standard.set(detected, forKey: row.defaultsKey)
            }
        }
        refreshStatuses()
    }

    @objc private func setMode(_ sender: NSPopUpButton) {
        if let mode = sender.selectedItem?.representedObject as? String {
            Prefs.atmosMode = mode
        }
    }
}

extension AtmosPrefsViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        refreshStatuses()
    }
}
