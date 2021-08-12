import re

def parseSqlFile(filename):
    queries = []

    with open(filename, 'r') as f:
        script = f.read()
    script = re.sub(r'\/\*.*?\*\/', '', script, flags=re.DOTALL)  # remove multiline comment
    script = re.sub(r'--.*$', '', script, flags=re.MULTILINE)  # remove single line comment

    lines = []
    for line in script.split('\n'):
        line = line.strip()
        if not line:
            continue

        if line.upper() == 'GO':
            query = '\n'.join(lines)
            queries.append(query)
            lines = [] 
        else: 
            lines.append(line)           

    return queries

def parseHtmlFile(filename):
    with open(filename, 'r') as f:
        return f.read().replace('\n', '')