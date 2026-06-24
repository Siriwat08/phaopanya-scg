const fs = require('fs');
const path = require('path');

const srcDir = path.join(__dirname, 'src');
const docsDir = path.join(__dirname, 'docs');
const rootDir = __dirname;

const newVersion = '5.5.021';
const dateStr = '2026-06-23';
const newLog =  *   v () — SECURITY & PERFORMANCE DEEP DIVE (17 FIXES):
 *     - [17_SearchService] C1-C3 (Performance), H1-H2 (Robustness), M1-M2 (PII/Security)
 *     - [18_ServiceSCG] C4-C7 (AuthZ & Concurrency), H4-H6 (Data Integrity), M3-M6 (ReDoS & Edge Cases)
 *     - [21_AliasService] C1 update parameter signature fastLookupByShipToName;

// Update all .gs files
function updateGSFiles(dir) {
    const files = fs.readdirSync(dir);
    for (const file of files) {
        const fullPath = path.join(dir, file);
        if (fs.statSync(fullPath).isDirectory()) {
            updateGSFiles(fullPath);
        } else if (fullPath.endsWith('.gs')) {
            let content = fs.readFileSync(fullPath, 'utf8');
            
            // Bump Version
            content = content.replace(/VERSION:\s*5\.5\.\d{3}/, VERSION: );
            
            // Insert Changelog before the previous one if not already there
            if (!content.includes()) {
                content = content.replace(/(\* ===================================================\r?\n)(\s*\*   v5\.5\.\d{3})/, $1\n);
            }
            
            fs.writeFileSync(fullPath, content, 'utf8');
        }
    }
}

updateGSFiles(srcDir);
console.log('Done updating .gs files');
