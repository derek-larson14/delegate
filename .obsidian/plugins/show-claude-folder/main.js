const { Plugin, TFolder, TFile } = require('obsidian');

module.exports = class ShowClaudePlugin extends Plugin {
    async onload() {
        // Wait for workspace to be ready
        this.app.workspace.onLayoutReady(() => {
            // Small delay to ensure file explorer is fully initialized
            setTimeout(() => {
                this.showClaudeFolder();
            }, 100);
        });

        // Re-show on file explorer refresh
        this.registerEvent(
            this.app.workspace.on('layout-change', () => {
                this.showClaudeFolder();
            })
        );

        // Poll for external changes (Claude Code, terminal, etc.)
        // Obsidian doesn't watch dotfiles, so we check disk every 2s
        // Only adds missing files and removes deleted ones — never tears down
        // existing registrations (Obsidian handles its own renames/edits)
        this.pollInterval = setInterval(() => {
            this.syncExternalChanges();
        }, 2000);
    }

    async syncExternalChanges() {
        const vault = this.app.vault;
        const adapter = vault.adapter;

        try {
            const exists = await adapter.exists('.claude');
            if (!exists) return;

            const claudeFolder = vault.getAbstractFileByPath('.claude');
            if (!claudeFolder) {
                // .claude not registered yet — do full registration
                await this.showClaudeFolder();
                return;
            }

            // Get what's on disk
            const diskFiles = new Set();
            await this.collectDiskPaths(adapter, '.claude', diskFiles);

            // Get what's registered in vault
            const vaultFiles = new Set();
            this.collectVaultPaths(claudeFolder, vaultFiles);

            // Find files on disk but not in vault (new external files)
            let changed = false;
            for (const path of diskFiles) {
                if (!vault.fileMap[path]) {
                    await this.registerFile(path);
                    changed = true;
                }
            }

            // Find files in vault but not on disk (externally deleted)
            for (const path of vaultFiles) {
                if (!diskFiles.has(path)) {
                    this.unregisterFile(path);
                    changed = true;
                }
            }

            if (changed) {
                this.forceFileExplorerRebuild();
            }
        } catch (e) {
            // .claude might not exist yet
        }
    }

    async collectDiskPaths(adapter, dirPath, paths) {
        const list = await adapter.list(dirPath);
        for (const f of list.files) paths.add(f);
        for (const d of list.folders) {
            paths.add(d);
            await this.collectDiskPaths(adapter, d, paths);
        }
    }

    collectVaultPaths(folder, paths) {
        if (!folder || !folder.children) return;
        for (const child of folder.children) {
            if (!child || !child.path) continue;
            paths.add(child.path);
            if (child instanceof TFolder) {
                this.collectVaultPaths(child, paths);
            }
        }
    }

    async registerFile(filePath) {
        const vault = this.app.vault;
        const adapter = vault.adapter;

        // Find parent folder
        const parentPath = filePath.substring(0, filePath.lastIndexOf('/'));
        const parentFolder = vault.getAbstractFileByPath(parentPath);
        if (!parentFolder) return;

        const stat = await adapter.stat(filePath);
        if (!stat) return;

        if (stat.type === 'folder') {
            const subfolder = new TFolder(vault, filePath);
            subfolder.parent = parentFolder;
            subfolder.vault = vault;
            const parts = filePath.split('/');
            subfolder.name = parts[parts.length - 1];

            if (!parentFolder.children) parentFolder.children = [];
            parentFolder.children.push(subfolder);
            vault.fileMap[filePath] = subfolder;

            // Load contents of new folder
            await this.loadClaudeContents(subfolder);
        } else {
            const file = new TFile(vault, filePath);
            file.parent = parentFolder;
            file.vault = vault;
            file.stat = stat;

            const parts = filePath.split('/');
            file.name = parts[parts.length - 1];
            file.basename = file.name.replace(/\.[^/.]+$/, '');
            file.extension = file.name.includes('.') ?
                file.name.split('.').pop() : '';

            if (!parentFolder.children) parentFolder.children = [];
            parentFolder.children.push(file);
            vault.fileMap[filePath] = file;
        }
    }

    unregisterFile(filePath) {
        const vault = this.app.vault;
        const file = vault.fileMap[filePath];
        if (!file) return;

        // Remove from parent's children
        if (file.parent && file.parent.children) {
            const idx = file.parent.children.indexOf(file);
            if (idx > -1) file.parent.children.splice(idx, 1);
        }

        // Remove from fileMap (recursively for folders)
        if (file instanceof TFolder) {
            this.removeFromFileMap(file);
        } else {
            delete vault.fileMap[filePath];
        }
    }

    async showClaudeFolder() {
        const vault = this.app.vault;
        const adapter = vault.adapter;

        try {
            // Check if .claude exists
            const exists = await adapter.exists('.claude');
            if (!exists) {
                return;
            }

            // Get the root folder
            const root = vault.getRoot();

            // Check if .claude is already in the vault
            let claudeFolder = vault.getAbstractFileByPath('.claude');

            if (!claudeFolder) {
                // Create a TFolder instance for .claude
                claudeFolder = new TFolder(vault, '.claude');
                claudeFolder.parent = root;

                // Add to vault's file map
                if (!root.children) {
                    root.children = [];
                }

                // Add .claude to root's children if not already there
                if (!root.children.includes(claudeFolder)) {
                    root.children.push(claudeFolder);
                }

                // Register in vault's fileMap
                vault.fileMap['.claude'] = claudeFolder;

                // Load all files and subfolders in .claude
                await this.loadClaudeContents(claudeFolder);

                // Force complete file explorer rebuild
                this.forceFileExplorerRebuild();
            } else {
                // Even if it exists, force a rebuild
                this.forceFileExplorerRebuild();
            }

        } catch (error) {
            console.error('Error showing .claude folder:', error);
        }
    }

    forceFileExplorerRebuild() {
        const leaves = this.app.workspace.getLeavesOfType('file-explorer');

        for (const leaf of leaves) {
            const fileExplorer = leaf.view;

            if (fileExplorer) {
                // Get the .claude folder
                const claudeFolder = this.app.vault.getAbstractFileByPath('.claude');

                // Try multiple approaches to force refresh

                // 1. If there's a tree, rebuild it properly
                if (fileExplorer.tree) {
                    // Find or create the tree item for .claude
                    const rootItem = fileExplorer.tree.root || fileExplorer.tree;

                    // Look for existing .claude item
                    let claudeItem = null;
                    if (rootItem.vChildren && rootItem.vChildren.children) {
                        claudeItem = rootItem.vChildren.children.find(
                            item => item.file && item.file.path === '.claude'
                        );
                    }

                    // If not found, try to create it
                    if (!claudeItem && fileExplorer.createFolderDom) {
                        claudeItem = fileExplorer.createFolderDom(claudeFolder);

                        // Add to tree
                        if (rootItem.vChildren && rootItem.vChildren.children) {
                            rootItem.vChildren.children.push(claudeItem);
                        }
                    }

                    // Make sure it's expandable
                    if (claudeItem) {
                        claudeItem.collapsed = false;
                        if (claudeItem.setCollapsed) {
                            claudeItem.setCollapsed(false);
                        }
                    }

                    // Recompute scroll
                    if (fileExplorer.tree.infinityScroll) {
                        fileExplorer.tree.infinityScroll.invalidateAll();
                        fileExplorer.tree.infinityScroll.compute();
                    }
                }

                // 2. Trigger sort which rebuilds the tree
                if (fileExplorer.sort) {
                    fileExplorer.sort();
                } else if (fileExplorer.requestSort) {
                    fileExplorer.requestSort();
                }

                // 3. Trigger events that might cause refresh
                this.app.vault.trigger('create', claudeFolder);

                // Recursively trigger for all children and subfolders
                this.triggerCreateForAll(claudeFolder);
            }
        }
    }

    triggerCreateForAll(folder) {
        if (!folder || !folder.children) return;

        for (const child of folder.children) {
            this.app.vault.trigger('create', child);

            // If it's a folder, recurse into it
            if (child.children) {
                this.triggerCreateForAll(child);
            }
        }
    }

    async loadClaudeContents(parentFolder) {
        const adapter = this.app.vault.adapter;
        const vault = this.app.vault;

        try {
            const list = await adapter.list(parentFolder.path);

            // Initialize children array if needed
            if (!parentFolder.children) {
                parentFolder.children = [];
            }

            // Process files
            for (const filePath of list.files) {
                if (!vault.fileMap[filePath]) {
                    const file = new TFile(vault, filePath);

                    // Set up all required properties
                    file.parent = parentFolder;
                    file.vault = vault;

                    // Get file stats (required for file to show)
                    const stat = await adapter.stat(filePath);
                    if (stat) {
                        file.stat = stat;

                        // Extract file info from path
                        const parts = filePath.split('/');
                        file.name = parts[parts.length - 1];
                        file.basename = file.name.replace(/\.[^/.]+$/, '');
                        file.extension = file.name.includes('.') ?
                            file.name.split('.').pop() : '';
                    }

                    // Add to parent's children
                    parentFolder.children.push(file);

                    // Register in vault's fileMap
                    vault.fileMap[filePath] = file;
                }
            }

            // Process subfolders
            for (const folderPath of list.folders) {
                if (!vault.fileMap[folderPath]) {
                    const subfolder = new TFolder(vault, folderPath);

                    // Set up folder properties
                    subfolder.parent = parentFolder;
                    subfolder.vault = vault;

                    // Extract folder name
                    const parts = folderPath.split('/');
                    subfolder.name = parts[parts.length - 1];

                    // Add to parent's children
                    parentFolder.children.push(subfolder);

                    // Register in vault's fileMap
                    vault.fileMap[folderPath] = subfolder;

                    // Recursively load subfolder contents
                    await this.loadClaudeContents(subfolder);
                }
            }

            // Sort children like Obsidian does (folders first, then files)
            parentFolder.children.sort((a, b) => {
                const aIsFolder = a instanceof TFolder;
                const bIsFolder = b instanceof TFolder;

                if (aIsFolder && !bIsFolder) return -1;
                if (!aIsFolder && bIsFolder) return 1;

                // Same type, sort alphabetically
                return a.name.localeCompare(b.name);
            });

        } catch (error) {
            console.error('Error loading contents for', parentFolder.path, ':', error);
        }
    }

    onunload() {
        if (this.pollInterval) {
            clearInterval(this.pollInterval);
        }

        // Clean up: remove .claude from vault
        const vault = this.app.vault;
        const claudeFolder = vault.getAbstractFileByPath('.claude');

        if (claudeFolder && claudeFolder.parent) {
            const index = claudeFolder.parent.children.indexOf(claudeFolder);
            if (index > -1) {
                claudeFolder.parent.children.splice(index, 1);
            }

            // Remove from fileMap
            this.removeFromFileMap(claudeFolder);

            // Don't force rebuild during unload - causes errors
            // The next load will handle the rebuild
        }
    }

    removeFromFileMap(folder) {
        const vault = this.app.vault;

        // Safety check for folder
        if (!folder || !folder.path) {
            return;
        }

        // Remove folder from fileMap
        delete vault.fileMap[folder.path];

        // Remove all children
        if (folder.children) {
            for (const child of folder.children) {
                // Safety check for child
                if (!child || !child.path) {
                    continue;
                }

                if (child instanceof TFolder) {
                    this.removeFromFileMap(child);
                } else {
                    delete vault.fileMap[child.path];
                }
            }
        }
    }
};
