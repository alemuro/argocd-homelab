#!/usr/bin/env python3
import subprocess
import json
import argparse
import sys

def main():
    parser = argparse.ArgumentParser(description="Comprova actualitzacions d'imatges Docker amb Renovate.")
    parser.add_argument('--all', '-a', action='store_true', help="Mostra totes les imatges, incloses les que estan al dia i les que usen tag 'latest'.")
    args = parser.parse_args()

    show_all = args.all
    if show_all:
        print("🔍 Executant Renovate per cercar actualitzacions (mostrant TOTES les imatges)...\n")
    else:
        print("🔍 Executant Renovate per cercar actualitzacions pendents...\n")
        
    cmd = ['npx', '-y', 'renovate', '--platform=local', '--dry-run=lookup']
    env = dict(dict(__import__('os').environ), LOG_LEVEL='debug', LOG_FORMAT='json')
    
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env)
    
    header = f"{'FITXER':<45} | {'IMATGE':<38} | {'TAG ACTUAL':<12} | {'ESTAT / ACTUALITZACIÓ'}"
    rows = []
    
    for line in proc.stdout:
        try:
            data = json.loads(line)
            if 'config' in data and 'regex' in data['config']:
                regex_files = data['config']['regex']
                for pf in regex_files:
                    pname = pf.get('packageFile', '')
                    for dep in pf.get('deps', []):
                        depName = dep.get('depName')
                        curr = str(dep.get('currentValue'))
                        updates = dep.get('updates', [])
                        
                        version_updates = [
                            f"{u.get('updateType')}: {u.get('newValue')}"
                            for u in updates
                            if u.get('newValue') and u.get('newValue') != curr and u.get('updateType') != 'pinDigest'
                        ]
                        has_digest_update = any(u.get('updateType') == 'pinDigest' for u in updates)
                        
                        if curr == 'latest':
                            if not show_all:
                                continue
                            status_symbol = "ℹ️ "
                            up_str = "latest (nova digestió disponible)" if has_digest_update else "latest (al dia)"
                        elif version_updates:
                            status_symbol = "⚡"
                            up_str = ', '.join(version_updates)
                        else:
                            if not show_all:
                                continue
                            status_symbol = "🟢"
                            up_str = "Al dia"
                            
                        rows.append(f"{status_symbol} {pname:<43} | {depName:<38} | {curr:<12} | {up_str}")
        except Exception:
            pass

    if rows:
        print(header)
        print("-" * len(header))
        for row in rows:
            print(row)
    else:
        print("🎉 Tot està al dia! No hi ha actualitzacions pendents.")

if __name__ == '__main__':
    main()
