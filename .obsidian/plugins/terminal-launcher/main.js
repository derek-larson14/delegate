const { Plugin, PluginSettingTab, Setting, Notice } = require('obsidian');
const { exec } = require('child_process');

const MAC_TERMINALS = {
	'terminal': {
		name: 'Terminal.app',
		command: (path) => `open -a Terminal "${path}"`
	},
	'warp': {
		name: 'Warp',
		command: (path) => `open -a Warp "${path}"`
	},
	'iterm': {
		name: 'iTerm2',
		command: (path) => `open -a iTerm "${path}"`
	}
};

const WIN_TERMINALS = {
	'powershell': {
		name: 'PowerShell',
		command: (path) => `start powershell -NoExit -Command "cd '${path}'"`
	},
	'windowsterminal': {
		name: 'Windows Terminal',
		command: (path) => `wt -d "${path}"`
	},
	'cmd': {
		name: 'Command Prompt',
		command: (path) => `start cmd /k "cd /d "${path}""`
	}
};

function getTerminals() {
	return process.platform === 'win32' ? WIN_TERMINALS : MAC_TERMINALS;
}

function getDefaultTerminal() {
	return process.platform === 'win32' ? 'powershell' : 'terminal';
}

const DEFAULT_SETTINGS = {
	terminal: getDefaultTerminal()
};

class ClaudeLauncherPlugin extends Plugin {
	async onload() {
		// Add UI immediately (don't wait for settings)
		this.addRibbonIcon('square-terminal', 'Open Terminal', () => {
			this.openTerminal();
		});

		this.addCommand({
			id: 'open-terminal',
			name: 'Open Terminal',
			callback: () => {
				this.openTerminal();
			}
		});

		this.addSettingTab(new TerminalLauncherSettingTab(this.app, this));

		// Load settings in background
		await this.loadSettings();
	}

	async loadSettings() {
		this.settings = Object.assign({}, DEFAULT_SETTINGS, await this.loadData());
	}

	async saveSettings() {
		await this.saveData(this.settings);
	}

	openTerminal() {
		const vaultPath = this.app.vault.adapter.basePath;
		const terminals = getTerminals();
		const terminal = terminals[this.settings.terminal];

		if (!terminal) {
			// Fall back to platform default if saved terminal not available
			const defaultKey = getDefaultTerminal();
			const defaultTerminal = terminals[defaultKey];
			if (defaultTerminal) {
				this.settings.terminal = defaultKey;
				this.saveSettings();
				this.openTerminal();
				return;
			}
			new Notice('No compatible terminal configured');
			return;
		}

		const command = terminal.command(vaultPath);

		exec(command, (error) => {
			if (error) {
				new Notice(`Failed to open ${terminal.name}: ${error.message}`);
				console.error('Terminal Launcher error:', error);
			} else {
				new Notice(`Opening ${terminal.name}...`);
			}
		});
	}
}

class TerminalLauncherSettingTab extends PluginSettingTab {
	constructor(app, plugin) {
		super(app, plugin);
		this.plugin = plugin;
	}

	display() {
		const { containerEl } = this;
		containerEl.empty();

		containerEl.createEl('h2', { text: 'Terminal Launcher Settings' });

		const terminals = getTerminals();

		new Setting(containerEl)
			.setName('Terminal')
			.setDesc('Which terminal app to use')
			.addDropdown(dropdown => {
				Object.entries(terminals).forEach(([key, value]) => {
					dropdown.addOption(key, value.name);
				});
				dropdown.setValue(this.plugin.settings.terminal);
				dropdown.onChange(async (value) => {
					this.plugin.settings.terminal = value;
					await this.plugin.saveSettings();
				});
			});
	}
}

module.exports = ClaudeLauncherPlugin;
