const { Plugin, PluginSettingTab, Setting } = require('obsidian');

const DEFAULT_SETTINGS = {
    pairs: [
        { taskFile: 'tasks.md', archiveFile: 'archive/archived-tasks.md' },
        { taskFile: 'delegation.md', archiveFile: 'archive/claude-completed.md' }
    ]
};

module.exports = class AutoArchivePlugin extends Plugin {
    async onload() {
        await this.loadSettings();

        // Listen for file modifications
        this.registerEvent(
            this.app.vault.on('modify', async (file) => {
                const pair = this.settings.pairs.find(p => p.taskFile === file.path);
                if (pair) {
                    await this.checkForCompletedTasks(file, pair);
                }
            })
        );

        // Settings tab
        this.addSettingTab(new AutoArchiveSettingTab(this.app, this));
    }

    async loadSettings() {
        const saved = await this.loadData();
        if (saved && saved.pairs) {
            this.settings = saved;
        } else if (saved && saved.taskFile) {
            // Migrate from old single-pair format
            this.settings = {
                pairs: [
                    { taskFile: saved.taskFile, archiveFile: saved.archiveFile },
                    { taskFile: 'delegation.md', archiveFile: 'archive/claude-completed.md' }
                ]
            };
            await this.saveSettings();
        } else {
            this.settings = Object.assign({}, DEFAULT_SETTINGS);
        }
    }

    async saveSettings() {
        await this.saveData(this.settings);
    }

    async checkForCompletedTasks(file, pair) {
        // DON'T process any archive file
        if (this.settings.pairs.some(p => p.archiveFile === file.path)) {
            return;
        }

        const content = await this.app.vault.read(file);
        const lines = content.split('\n');

        let completedTasks = [];
        let remainingLines = [];

        lines.forEach((line, index) => {
            if (line.match(/^[\s]*[-*]\s*\[x\]/i)) {
                // This is a completed task - find its context
                const taskWithContext = this.addParentContext(lines, index, line);
                completedTasks.push(taskWithContext);
            } else {
                remainingLines.push(line);
            }
        });

        if (completedTasks.length > 0) {
            await this.app.vault.modify(file, remainingLines.join('\n'));
            await this.archiveTasks(completedTasks, pair.archiveFile);
        }
    }

    addParentContext(lines, taskIndex, taskLine) {
        // Get the indentation level of the current task
        const currentIndent = taskLine.match(/^(\s*)/)[1].length;

        // Look backwards for parent tasks or headings
        let parentContext = '';

        for (let i = taskIndex - 1; i >= 0; i--) {
            const line = lines[i].trim();
            if (!line) continue; // Skip empty lines

            const lineIndent = lines[i].match(/^(\s*)/)[1].length;

            // Check for parent task (less indented task)
            if (lines[i].match(/^[\s]*[-*]\s*\[.\]/) && lineIndent < currentIndent) {
                const parentTask = line.replace(/^[-*]\s*\[.\]\s*/, '').trim();
                parentContext = `> ${parentTask}`;
                break;
            }

            // Check for heading
            if (line.match(/^#+\s+/)) {
                const heading = line.replace(/^#+\s+/, '').trim();
                parentContext = `> ${heading}`;
                break;
            }

            // Check for list item (non-task) that could be a parent
            if (lines[i].match(/^[\s]*[-*]\s+[^\[]/) && lineIndent < currentIndent) {
                const parentItem = line.replace(/^[-*]\s+/, '').trim();
                parentContext = `> ${parentItem}`;
                break;
            }
        }

        // Extract just the task text (without bullet point and checkbox)
        const taskText = taskLine.replace(/^[\s]*[-*]\s*\[x\]\s*/i, '').trim();

        // Create clean task format
        const cleanTask = `- [x] ${taskText}`;

        // Add parent context if found
        if (parentContext) {
            return `${cleanTask} ${parentContext}`;
        }

        return cleanTask;
    }

    async archiveTasks(tasks, archiveFilePath) {
        const now = new Date();
        const today = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, '0')}-${String(now.getDate()).padStart(2, '0')}`;

        let archiveFile = this.app.vault.getAbstractFileByPath(archiveFilePath);

        if (!archiveFile) {
            // Create folder if needed
            const folderPath = archiveFilePath.substring(0, archiveFilePath.lastIndexOf('/'));
            if (folderPath) {
                await this.app.vault.createFolder(folderPath).catch(() => {});
            }
            await this.app.vault.create(archiveFilePath, '# Archived Tasks\n\n');
            archiveFile = this.app.vault.getAbstractFileByPath(archiveFilePath);
        }

        const archiveContent = await this.app.vault.read(archiveFile);
        const lines = archiveContent.split('\n');

        // Check if today's header already exists
        const todayHeader = `## ${today}`;
        const headerIndex = lines.findIndex(line => line === todayHeader);

        if (headerIndex !== -1) {
            // Header exists, insert tasks right after the header (most recent at top)
            lines.splice(headerIndex + 1, 0, ...tasks);
        } else {
            // Header doesn't exist, add it at the top (after main heading)
            let insertIndex = 0;
            for (let i = 0; i < lines.length; i++) {
                if (lines[i].startsWith('# ')) {
                    insertIndex = i + 1;
                    // Skip any blank lines after the main heading
                    while (insertIndex < lines.length && lines[insertIndex].trim() === '') {
                        insertIndex++;
                    }
                    break;
                }
            }
            lines.splice(insertIndex, 0, todayHeader, ...tasks, '');
        }

        await this.app.vault.modify(archiveFile, lines.join('\n'));
    }
};

class AutoArchiveSettingTab extends PluginSettingTab {
    constructor(app, plugin) {
        super(app, plugin);
        this.plugin = plugin;
    }

    display() {
        const { containerEl } = this;
        containerEl.empty();

        containerEl.createEl('h2', { text: 'Auto Archive Tasks Settings' });

        this.plugin.settings.pairs.forEach((pair, index) => {
            const pairHeader = new Setting(containerEl)
                .setName(`Pair ${index + 1}`)
                .setHeading();

            if (this.plugin.settings.pairs.length > 1) {
                pairHeader.addButton(btn => btn
                    .setButtonText('Remove')
                    .onClick(async () => {
                        this.plugin.settings.pairs.splice(index, 1);
                        await this.plugin.saveSettings();
                        this.display();
                    }));
            }

            new Setting(containerEl)
                .setName('Task file')
                .setDesc('File to watch for completed tasks')
                .addText(text => text
                    .setPlaceholder('tasks.md')
                    .setValue(pair.taskFile)
                    .onChange(async (value) => {
                        this.plugin.settings.pairs[index].taskFile = value;
                        await this.plugin.saveSettings();
                    }));

            new Setting(containerEl)
                .setName('Archive file')
                .setDesc('Where to move completed tasks')
                .addText(text => text
                    .setPlaceholder('archive/archived-tasks.md')
                    .setValue(pair.archiveFile)
                    .onChange(async (value) => {
                        this.plugin.settings.pairs[index].archiveFile = value;
                        await this.plugin.saveSettings();
                    }));
        });

        new Setting(containerEl)
            .addButton(btn => btn
                .setButtonText('Add pair')
                .setCta()
                .onClick(async () => {
                    this.plugin.settings.pairs.push({ taskFile: '', archiveFile: '' });
                    await this.plugin.saveSettings();
                    this.display();
                }));
    }
}
