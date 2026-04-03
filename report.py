import datetime
import glob
import html
import json
import os
import shutil

reports = sorted(glob.glob("reports/**/cve-report-*-*.json", recursive=True))

apps = {}
for rpath in reports:
    filename = os.path.basename(rpath)
    # Expected format: cve-report-NAME-ARCH.json
    parts = filename.replace("cve-report-", "").replace(".json", "").split("-")
    if len(parts) >= 2:
        arch = parts[-1]
        name = "-".join(parts[:-1])
    else:
        name = filename.replace("cve-report-", "").replace(".json", "")
        arch = "unknown"

    try:
        with open(rpath) as f:
            data = json.load(f)
        vegops = data.get("vegops", {})
        source_image = vegops.get("sourceImage", name)
        repository = vegops.get("repository", source_image)
        release_tag = vegops.get("releaseTag")
        stream_tag = vegops.get("streamTag")
        published_tags = vegops.get("publishedTags", [])
        app_key = f"{repository}:{release_tag}" if release_tag else repository

        if app_key not in apps:
            apps[app_key] = {
                "source_images": set(),
                "repository": repository,
                "release_tag": release_tag,
                "stream_tag": stream_tag,
                "published_tags": set(),
                "archs": set(),
                "vulns": {},
            }

        app = apps[app_key]
        app["source_images"].add(source_image)
        app["archs"].add(arch)
        for tag in published_tags:
            app["published_tags"].add(tag)

        matches = data.get("matches", [])
        for m in matches:
            artifact_name = m.get("artifact", {}).get("name", "unknown")
            artifact_version = m.get("artifact", {}).get("version", "unknown")
            pkg = f"{artifact_name}@{artifact_version}"
            
            for v in m.get("vulnerabilities", [m.get("vulnerability", {})]):
                vid = v.get("id", "N/A")
                key = (vid, pkg)
                
                if key not in app["vulns"]:
                    app["vulns"][key] = {
                        "id": vid,
                        "severity": v.get("severity", "Unknown"),
                        "description": v.get("description", "")[:200],
                        "package": pkg,
                        "fixed": v.get("fix", {}).get("versions", []),
                        "archs": set()
                    }
                app["vulns"][key]["archs"].add(arch)
    except Exception:
        pass

severity_order = {"Critical": 0, "High": 1, "Medium": 2, "Low": 3, "Negligible": 4, "Unknown": 5}
now = datetime.datetime.now(datetime.UTC).strftime("%Y-%m-%d %H:%M UTC")

# Summary stats
total = {"Critical": 0, "High": 0, "Medium": 0, "Low": 0}
for app in apps.values():
    for v in app["vulns"].values():
        sev = v["severity"]
        if sev in total:
            total[sev] += 1

page = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>VegOps CVE Dashboard</title>
  <link rel="icon" type="image/png" href="favicon.png">
  <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
  <style>
    :root {{
      --bg: #0f172a;           /* slate-900 */
      --surface: #1e293b;      /* slate-800 */
      --surface-hover: #334155;/* slate-700 */
      --border: #334155;       /* slate-700 */
      --text: #f8fafc;         /* slate-50 */
      --text-muted: #94a3b8;   /* slate-400 */
      
      --critical: #ef4444;     /* red-500 */
      --critical-bg: #7f1d1d;  /* red-900 (20%) */
      
      --high: #f97316;         /* orange-500 */
      --high-bg: #7c2d12;      /* orange-900 */
      
      --medium: #eab308;       /* yellow-500 */
      --medium-bg: #713f12;    /* yellow-900 */
      
      --low: #22c55e;          /* green-500 */
      --low-bg: #14532d;       /* green-900 */
      
      --unknown: #64748b;      /* slate-500 */
      --unknown-bg: #334155;   /* slate-700 */
      
      --accent: #38bdf8;       /* sky-400 */
    }}
    
    * {{ margin: 0; padding: 0; box-sizing: border-box; }}
    
    body {{ 
      font-family: 'Inter', -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
      background: var(--bg); 
      color: var(--text); 
      padding: 1rem; 
      line-height: 1.5;
      -webkit-font-smoothing: antialiased;
    }}
    
    @media (min-width: 768px) {{
      body {{ padding: 2rem; }}
    }}
    
    .container {{
      max-width: 1200px;
      margin: 0 auto;
    }}
    
    header {{
      margin-bottom: 2rem;
      border-bottom: 1px solid var(--border);
      padding-bottom: 1.5rem;
    }}
    
    h1 {{ 
      color: var(--text); 
      font-size: 1.75rem;
      font-weight: 700;
      letter-spacing: -0.025em;
      margin-bottom: 0.5rem;
      display: flex;
      align-items: center;
      gap: 0.75rem;
    }}
    
    @media (min-width: 768px) {{
      h1 {{ font-size: 2.25rem; margin-bottom: 0.25rem; }}
    }}
    
    h1::before {{
      content: '';
      display: inline-block;
      width: 20px;
      height: 20px;
      background: var(--accent);
      border-radius: 5px;
      box-shadow: 0 0 15px rgba(56, 189, 248, 0.4);
    }}
    
    @media (min-width: 768px) {{
      h1::before {{ width: 24px; height: 24px; border-radius: 6px; }}
    }}
    
    .timestamp {{ 
      color: var(--text-muted); 
      font-size: 0.875rem; 
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }}
    
    .summary {{ 
      display: grid; 
      grid-template-columns: 1fr; 
      gap: 1rem; 
      margin-bottom: 2.5rem; 
    }}
    
    @media (min-width: 480px) {{
      .summary {{ grid-template-columns: repeat(2, 1fr); }}
    }}
    
    @media (min-width: 1024px) {{
      .summary {{ grid-template-columns: repeat(5, 1fr); }}
    }}
    
    .card {{ 
      background: var(--surface); 
      border: 1px solid var(--border); 
      border-radius: 12px;
      padding: 1.25rem; 
      box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
      transition: transform 0.2s ease, box-shadow 0.2s ease;
      display: flex;
      flex-direction: column;
      justify-content: space-between;
    }}
    
    .card:hover {{
      transform: translateY(-2px);
      box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
      border-color: var(--surface-hover);
    }}
    
    .card h3 {{ 
      color: var(--text-muted); 
      font-size: 0.75rem;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      margin-bottom: 0.5rem; 
    }}
    
    .card .count {{ 
      font-size: 2rem; 
      font-weight: 700; 
      line-height: 1;
    }}
    
    .count-text {{ color: var(--text); }}
    .count.critical {{ color: var(--critical); text-shadow: 0 0 12px rgba(239, 68, 68, 0.3); }}
    .count.high {{ color: var(--high); text-shadow: 0 0 12px rgba(249, 115, 22, 0.3); }}
    .count.medium {{ color: var(--medium); }}
    .count.low {{ color: var(--low); }}
    
    .image-section {{ 
      margin-bottom: 2rem; 
      background: var(--surface);
      border: 1px solid var(--border);
      border-radius: 12px;
      overflow: hidden;
      box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1);
    }}
    
    .image-header {{
      padding: 1rem 1.25rem;
      background: rgba(15, 23, 42, 0.4);
      border-bottom: 1px solid var(--border);
      display: flex;
      align-items: center;
      justify-content: space-between;
      flex-wrap: wrap;
      gap: 0.75rem;
    }}

    .image-summary {{
      list-style: none;
      cursor: pointer;
    }}

    .image-summary::-webkit-details-marker {{
      display: none;
    }}

    .image-summary::marker {{
      content: "";
    }}

    .image-summary:hover {{
      background: rgba(15, 23, 42, 0.55);
    }}

    .toggle-icon {{
      display: inline-flex;
      align-items: center;
      justify-content: center;
      width: 1.5rem;
      height: 1.5rem;
      color: var(--text-muted);
      flex-shrink: 0;
      transition: transform 0.2s ease, color 0.2s ease;
    }}

    .toggle-spacer {{
      display: block;
      width: 1.5rem;
      height: 1.5rem;
      flex-shrink: 0;
    }}

    .image-section details[open] .toggle-icon {{
      transform: rotate(90deg);
      color: var(--accent);
    }}
    
    .image-section h2 {{ 
      color: var(--text); 
      font-size: 1.125rem;
      font-weight: 600;
      display: flex;
      align-items: center;
      gap: 0.5rem;
    }}

    .image-heading {{
      display: flex;
      flex-direction: column;
      gap: 0.35rem;
      min-width: 0;
    }}

    .image-subtitle {{
      color: var(--text-muted);
      font-size: 0.85rem;
      display: flex;
      flex-wrap: wrap;
      gap: 0.5rem;
    }}

    .image-meta {{
      display: flex;
      flex-wrap: wrap;
      gap: 0.5rem;
    }}

    .meta-badge {{
      display: inline-flex;
      align-items: center;
      gap: 0.35rem;
      border: 1px solid rgba(56, 189, 248, 0.18);
      background: rgba(56, 189, 248, 0.08);
      color: var(--accent);
      padding: 0.2rem 0.5rem;
      border-radius: 9999px;
      font-size: 0.75rem;
      white-space: nowrap;
    }}
    
    .image-section h2::before {{
      content: '📦';
      font-size: 1rem;
    }}
    
    .table-wrapper {{
      overflow-x: auto;
    }}
    
    table {{ 
      width: 100%; 
      border-collapse: collapse; 
      text-align: left;
    }}
    
    th, td {{ 
      padding: 1rem 1.25rem; 
      border-bottom: 1px solid var(--border); 
    }}
    
    th {{ 
      color: var(--text-muted); 
      font-weight: 600; 
      font-size: 0.875rem;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      background: rgba(15, 23, 42, 0.2);
    }}
    
    tbody tr {{
      transition: background-color 0.15s ease;
    }}
    
    tbody tr:last-child td {{
      border-bottom: none;
    }}
    
    tbody tr:hover {{
      background-color: rgba(255, 255, 255, 0.02);
    }}
    
    /* Responsive Table to Cards */
    @media (max-width: 767px) {{
      thead {{ display: none; }}
      
      table, tbody, tr, td {{ 
        display: block; 
        width: 100%;
      }}
      
      tr {{
        padding: 1rem 0;
        border-bottom: 4px solid var(--bg);
      }}
      
      tr:last-child {{
        border-bottom: none;
      }}
      
      td {{
        border: none;
        padding: 0.5rem 1.25rem;
        display: flex;
        justify-content: space-between;
        align-items: flex-start;
        text-align: right;
      }}
      
      td::before {{
        content: attr(data-label);
        font-weight: 600;
        text-transform: uppercase;
        font-size: 0.75rem;
        color: var(--text-muted);
        display: block;
        text-align: left;
        margin-right: 1rem;
        flex-shrink: 0;
        padding-top: 0.1rem;
      }}
      
      .cve-id, .package-name, .fixed-in, .description {{
        max-width: none;
        text-align: right;
      }}
      
      .description {{
        display: block;
        text-align: left;
        margin-top: 0.25rem;
      }}
      
      .description::before {{
        margin-bottom: 0.5rem;
      }}
    }}
    
    .cve-id {{
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
      font-size: 0.9rem;
      color: var(--text);
      font-weight: 500;
    }}
    
    .package-name {{
      font-weight: 500;
      color: var(--accent);
    }}
    
    .fixed-in {{
      font-family: ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace;
      font-size: 0.85rem;
      color: var(--low);
    }}
    
    .arch-badge {{
      font-size: 0.75rem;
      background: rgba(56, 189, 248, 0.1);
      color: var(--accent);
      padding: 0.2rem 0.5rem;
      border-radius: 4px;
      margin-right: 0.25rem;
      display: inline-block;
    }}

    .description {{
      color: var(--text-muted);
      font-size: 0.95rem;
      max-width: 400px;
      line-height: 1.6;
    }}
    
    .badge {{ 
      display: inline-flex;
      align-items: center;
      justify-content: center;
      padding: 0.25rem 0.6rem; 
      border-radius: 9999px; 
      font-size: 0.75rem; 
      font-weight: 600; 
      text-transform: uppercase;
      letter-spacing: 0.05em;
      white-space: nowrap;
    }}
    
    .badge-critical {{ background: var(--critical-bg); color: var(--critical); border: 1px solid rgba(239, 68, 68, 0.2); }}
    .badge-high {{ background: var(--high-bg); color: var(--high); border: 1px solid rgba(249, 115, 22, 0.2); }}
    .badge-medium {{ background: var(--medium-bg); color: var(--medium); border: 1px solid rgba(234, 179, 8, 0.2); }}
    .badge-low {{ background: var(--low-bg); color: var(--low); border: 1px solid rgba(34, 197, 94, 0.2); }}
    .badge-unknown {{ background: var(--unknown-bg); color: var(--unknown); border: 1px solid rgba(100, 116, 139, 0.2); }}
    
    .image-title-wrapper {{
      display: grid;
      grid-template-columns: 1.5rem minmax(0, auto);
      align-items: center;
      column-gap: 0.75rem;
      flex: 1;
      min-width: 200px;
    }}
    
    .status-badge {{
      display: inline-flex;
      align-items: center;
      gap: 0.375rem;
      padding: 0.375rem 0.75rem;
      border-radius: 6px;
      font-size: 0.875rem;
      font-weight: 500;
      background: rgba(34, 197, 94, 0.1);
      color: var(--low);
      border: 1px solid rgba(34, 197, 94, 0.2);
    }}
    
    .status-badge.has-issues {{
      background: rgba(239, 68, 68, 0.1);
      color: var(--critical);
      border-color: rgba(239, 68, 68, 0.2);
    }}
    
    .status-dot {{
      width: 8px;
      height: 8px;
      border-radius: 50%;
      background: currentColor;
    }}
    
    .status-badge.has-issues .status-dot {{
      box-shadow: 0 0 8px currentColor;
      animation: pulse 2s infinite;
    }}

    .image-collapsible {{
      display: block;
    }}

    .image-collapsible:not([open]) .image-summary {{
      border-bottom: none;
    }}

    .image-header-static {{
      border-bottom: none;
    }}
    
    @keyframes pulse {{
      0% {{ opacity: 1; }}
      50% {{ opacity: 0.5; }}
      100% {{ opacity: 1; }}
    }}
  </style>
</head>
<body>
  <div class="container">
    <header>
      <h1>VegOps Security Dashboard</h1>
      <p class="timestamp">
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" style="vertical-align: middle; margin-right: 4px;"><circle cx="12" cy="12" r="10"></circle><polyline points="12 6 12 12 16 14"></polyline></svg>
        Generated on {now}
      </p>
    </header>
"""

page += '<div class="summary">'
for sev, count in total.items():
    cls = sev.lower()
    page += f'<div class="card"><h3>{sev}</h3><div class="count {cls}">{count}</div></div>'
page += f'<div class="card"><h3>Releases Scanned</h3><div class="count count-text">{len(apps)}</div></div>'
page += "</div>"

def app_sort_key(item):
    app = item[1]
    stream_tag = app["stream_tag"] or ""
    if stream_tag.isdigit():
        stream_key = (0, -int(stream_tag))
    else:
        stream_key = (1, stream_tag)
    return (
        app["repository"],
        stream_key,
        app["release_tag"] or "",
    )


for _, app in sorted(apps.items(), key=app_sort_key):
    vulns = list(app["vulns"].values())
    has_issues = len(vulns) > 0
    status_class = "has-issues" if has_issues else ""
    status_text = f"{len(vulns)} Issues" if has_issues else "Clean"
    display_name = app["repository"]
    if app["release_tag"]:
        display_name = f"{display_name}:{app['release_tag']}"

    subtitle_bits = []
    if app["stream_tag"]:
        subtitle_bits.append(f"stream {app['stream_tag']}")
    if app["source_images"]:
        subtitle_bits.append("source " + ", ".join(sorted(app["source_images"])))
    subtitle_html = ""
    if subtitle_bits:
        subtitle_html = '<div class="image-subtitle">' + "".join(
            f"<span>{html.escape(bit)}</span>" for bit in subtitle_bits
        ) + "</div>"

    meta_tags = []
    if app["published_tags"]:
        for tag in sorted(app["published_tags"], key=lambda tag: (tag != "latest", tag)):
            meta_tags.append(f'<span class="meta-badge">{html.escape(tag)}</span>')
    if app["archs"]:
        meta_tags.append(
            f'<span class="meta-badge">archs: {html.escape(", ".join(sorted(app["archs"])))}</span>'
        )
    meta_html = ""
    if meta_tags:
        meta_html = '<div class="image-meta">' + "".join(meta_tags) + "</div>"

    header_html = f'''
      <div class="image-title-wrapper">
        {'<span class="toggle-icon" aria-hidden="true"><svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="9 18 15 12 9 6"></polyline></svg></span>' if has_issues else '<span class="toggle-spacer" aria-hidden="true"></span>'}
        <div class="image-heading">
          <h2>{html.escape(display_name)}</h2>
          {subtitle_html}
          {meta_html}
        </div>
      </div>
      <div class="status-badge {status_class}">
        <div class="status-dot"></div>
        {status_text}
      </div>
    '''

    page += '<div class="image-section">'

    if vulns:
        vulns.sort(key=lambda v: severity_order.get(v["severity"], 99))
        page += f'''
        <details class="image-collapsible">
          <summary class="image-header image-summary">
            {header_html}
          </summary>
        '''
        page += '''
        <div class="table-wrapper">
          <table>
            <thead>
              <tr>
                <th>CVE ID</th>
                <th>Severity</th>
                <th>Package</th>
                <th>Arch</th>
                <th>Fixed Version</th>
                <th>Description</th>
              </tr>
            </thead>
            <tbody>
        '''
        for v in vulns:
            sev = v["severity"]
            badge_cls = f"badge-{sev.lower()}" if sev.lower() in ["critical","high","medium","low"] else "badge-unknown"
            fixed = ", ".join(v["fixed"]) if v["fixed"] else "Unpatched"
            archs = ", ".join(sorted(list(v["archs"])))
            desc = html.escape(v["description"])
            if len(desc) > 80:
                desc = desc[:77] + "..."
                
            page += f'''
              <tr>
                <td data-label="CVE ID" class="cve-id">{html.escape(v["id"])}</td>
                <td data-label="Severity"><span class="badge {badge_cls}">{sev}</span></td>
                <td data-label="Package" class="package-name">{html.escape(v["package"])}</td>
                <td data-label="Arch"><span class="arch-badge">{html.escape(archs)}</span></td>
                <td data-label="Fixed Version" class="fixed-in">{fixed}</td>
                <td data-label="Description" class="description" title="{html.escape(v.get('description', ''))}">{desc}</td>
              </tr>
            '''
        page += "</tbody></table></div></details>"
    else:
        page += f'''
      <div class="image-header image-header-static">
        {header_html}
      </div>
    '''
    page += "</div>"
    
page += "</div></body></html>"

with open("site/index.html", "w") as f:
    f.write(page)

# Copy favicon
if os.path.exists("logo.png"):
    shutil.copy("logo.png", "site/favicon.png")

print(f"Generated dashboard with {len(apps)} releases")
