import json
import sys

reference = json.load(sys.stdin)

for key, doc in reference.items():
    print(f'## {key}')
    print('<dl>')
    print(f'<dt>Name</dt><dd>{doc["name"]}</dd>')
    print(f'<dt>Type</dt><dd>{doc["type"]}</dd>')
    print(f'<dt>Usage</dt><dd>{doc["usage"]}</dd>')
    print('</dl>')
    print(doc["description"])
