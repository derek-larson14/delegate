const { Plugin, PluginSettingTab, Setting } = require('obsidian');

const DEFAULT_SETTINGS = {
    taskFile: 'tasks.md',
    archiveFile: 'archive/archived-tasks.md'
};

module.exports = class AutoArchivePlugin extends Plugin {
    async onload() {
        await this.loadSettings();

        // Listen for file modifications
        this.registerEvent(
            this.app.vault.on('modify', async (file) => {
                if (file.path === this.settings.taskFile) {
                    await this.checkForCompletedTasks(file);
                }
            })
        );

        // Settings tab
        this.addSettingTab(new AutoArchiveSettingTab(this.app, this));
    }

    async loadSettings() {
        this.settings = Object.assign({}, DEFAULT_SETTINGS, await this.loadData());
    }

    async saveSettings() {
        await this.saveData(this.settings);
    }

    async checkForCompletedTasks(file) {
        // DON'T process the archive file itself!
        if (file.path === this.settings.archiveFile) {
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
            await this.archiveTasks(completedTasks);
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

    async archiveTasks(tasks) {
        const archiveFilePath = this.settings.archiveFile;
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
            // Header exists, find end of this day's section and append there
            let insertIndex = headerIndex + 1;
            while (insertIndex < lines.length && !lines[insertIndex].startsWith('## ')) {
                insertIndex++;
            }
            // Insert before next header (or at end)
            lines.splice(insertIndex, 0, ...tasks);
        } else {
            // Header doesn't exist, add it with tasks at end
            lines.push('', todayHeader, ...tasks);
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

        new Setting(containerEl)
            .setName('Task file')
            .setDesc('File to watch for completed tasks (e.g., tasks.md)')
            .addText(text => text
                .setPlaceholder('tasks.md')
                .setValue(this.plugin.settings.taskFile)
                .onChange(async (value) => {
                    this.plugin.settings.taskFile = value;
                    await this.plugin.saveSettings();
                }));

        new Setting(containerEl)
            .setName('Archive file')
            .setDesc('Where to move completed tasks (e.g., archive/archived-tasks.md)')
            .addText(text => text
                .setPlaceholder('archive/archived-tasks.md')
                .setValue(this.plugin.settings.archiveFile)
                .onChange(async (value) => {
                    this.plugin.settings.archiveFile = value;
                    await this.plugin.saveSettings();
                }));
    }
}
