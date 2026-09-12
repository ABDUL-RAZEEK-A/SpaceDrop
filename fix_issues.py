import os
import re

def process_file(filepath):
    with open(filepath, 'r') as f:
        content = f.read()

    original = content

    # Replace withOpacity with withValues(alpha: )
    content = re.sub(r'\.withOpacity\((.*?)\)', r'.withValues(alpha: \1)', content)

    # Replace surfaceVariant with surfaceContainerHighest
    content = content.replace('surfaceVariant', 'surfaceContainerHighest')
    
    # Unnecessary toList() in spread (we'll do a simple heuristic or handle manually)
    content = content.replace('..._pendingRequests.map((r) => r).toList(),', '..._pendingRequests,') # just an example, will check manually if needed

    # Replace print( with debugPrint(
    if 'print(' in content:
        content = re.sub(r'\bprint\(', 'debugPrint(', content)
        if 'import \'package:flutter/foundation.dart\';' not in content and 'import "package:flutter/foundation.dart";' not in content:
            # add import after the first import or at top
            if 'import ' in content:
                content = content.replace('import ', "import 'package:flutter/foundation.dart';\nimport ", 1)
            else:
                content = "import 'package:flutter/foundation.dart';\n" + content

    if content != original:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"Fixed {filepath}")

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            process_file(os.path.join(root, file))
