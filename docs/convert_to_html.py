#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""Convert UniBase-AI-Integration-Guide.md to HTML with print-friendly styling"""

import markdown
import os

def convert_md_to_html():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    md_file = os.path.join(script_dir, 'UniBase-AI-Integration-Guide.md')
    html_file = os.path.join(script_dir, 'UniBase-AI-Integration-Guide.html')
    
    with open(md_file, 'r', encoding='utf-8') as f:
        md_content = f.read()
    
    md = markdown.Markdown(extensions=['tables', 'fenced_code', 'toc'])
    html_body = md.convert(md_content)
    
    html_template = '''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>UniBase AI Integration Guide</title>
    <style>
        @media print {
            body { font-size: 10pt; }
            pre { page-break-inside: avoid; }
            h1, h2, h3 { page-break-after: avoid; }
            table { page-break-inside: avoid; }
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            line-height: 1.6;
            max-width: 900px;
            margin: 0 auto;
            padding: 20px;
            color: #333;
            background: #fff;
        }
        
        h1 { 
            color: #2c3e50; 
            border-bottom: 3px solid #3498db; 
            padding-bottom: 10px;
            font-size: 2em;
        }
        
        h2 { 
            color: #34495e; 
            border-bottom: 2px solid #bdc3c7; 
            padding-bottom: 8px;
            margin-top: 2em;
            font-size: 1.5em;
        }
        
        h3 { 
            color: #7f8c8d; 
            margin-top: 1.5em;
            font-size: 1.2em;
        }
        
        code {
            background: #f4f4f4;
            padding: 2px 6px;
            border-radius: 3px;
            font-family: 'Consolas', 'Monaco', 'Courier New', monospace;
            font-size: 0.9em;
        }
        
        pre {
            background: #2d2d2d;
            color: #f8f8f2;
            padding: 15px;
            border-radius: 5px;
            overflow-x: auto;
            font-size: 0.85em;
            line-height: 1.4;
        }
        
        pre code {
            background: none;
            padding: 0;
            color: inherit;
        }
        
        table {
            border-collapse: collapse;
            width: 100%;
            margin: 1em 0;
            font-size: 0.9em;
        }
        
        th, td {
            border: 1px solid #ddd;
            padding: 10px 12px;
            text-align: left;
        }
        
        th {
            background: #3498db;
            color: white;
            font-weight: 600;
        }
        
        tr:nth-child(even) {
            background: #f9f9f9;
        }
        
        tr:hover {
            background: #f5f5f5;
        }
        
        blockquote {
            border-left: 4px solid #3498db;
            margin: 1em 0;
            padding: 10px 20px;
            background: #f8f9fa;
            color: #555;
        }
        
        hr {
            border: none;
            border-top: 2px solid #eee;
            margin: 2em 0;
        }
        
        a {
            color: #3498db;
            text-decoration: none;
        }
        
        a:hover {
            text-decoration: underline;
        }
        
        ul, ol {
            padding-left: 2em;
        }
        
        li {
            margin: 0.3em 0;
        }
        
        /* Special styling for constraint blocks */
        pre:first-of-type {
            background: #1a1a2e;
            border-left: 4px solid #e74c3c;
        }
        
        /* Print header */
        @media print {
            body::before {
                content: "UniBase AI Integration Guide v1.0";
                display: block;
                text-align: center;
                font-size: 8pt;
                color: #999;
                margin-bottom: 20px;
            }
        }
    </style>
</head>
<body>
''' + html_body + '''
</body>
</html>'''
    
    with open(html_file, 'w', encoding='utf-8') as f:
        f.write(html_template)
    
    print(f'HTML file created: {html_file}')
    print('Open in browser and use Ctrl+P to print/save as PDF')

if __name__ == '__main__':
    convert_md_to_html()
