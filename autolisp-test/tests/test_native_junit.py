#!/usr/bin/env python3
"""Vérifie les rapports du chemin C:RUN-NAMED avec clautolisp --host cador.

Exécution : python3 autolisp-test/tests/test_native_junit.py
Le moteur clautolisp doit être disponible dans PATH. Les fichiers sont temporaires.
"""
from pathlib import Path
import subprocess, tempfile, shutil, os, sys
def chemin_moteur(path):
 if sys.platform.startswith(('msys','cygwin')):
  return subprocess.check_output(['cygpath','-am',str(path)],text=True).strip()
 return Path(path).as_posix()
r=Path(__file__).resolve().parents[2]
r_moteur=chemin_moteur(r)
with tempfile.TemporaryDirectory() as t:
 t=Path(t).resolve().as_posix()
 for mode in ('ok','missing-suite','missing-test','failure-handler','error-handler','load-error'):
  report=Path(t)/f'{mode}.xml'
  args=[os.environ.get('CLAUTOLISP_TEST_BIN') or shutil.which('clautolisp') or 'clautolisp','-norc','--host','cador','--dialect','bricscad-v26','-x',f'(setq *tu:repo-dir* "{chemin_moteur(t)}" *outils-autolisp-root* "{r_moteur}")','-l',chemin_moteur(r/'autolisp-test/test-runner.lsp'),'-x',f'(setenv "AUTOLISP_TEST_JUNIT" "{chemin_moteur(report)}")','-x',"(setq *t:suites* (list (list \"native\" (list \"reussi\" '(lambda () T)))))"]
  if mode=='ok':expr='(C:RUN-NAMED "native" "reussi")'
  elif mode=='missing-suite':expr='(C:RUN-NAMED "absente" "reussi")'
  elif mode=='missing-test':expr='(C:RUN-NAMED "native" "absent")'
  elif mode=='load-error':expr="(setq *tu:load-failures* '((\"absent.lsp\" . \"inaccessible\")))"
  else:
   tag="'fail" if mode=='failure-handler' else 'nil'
   expr=f'(progn (setq *tu:junit-start* (t:millisecs) *tu:current-suite* "native" *tu:current-test* "interrompu" *t:throw-tag* {tag}) (tu:trap-error "erreur simulee"))'
  args+=['-x',expr,'-x','(C:WRITE-SUMMARY)','-x','(quit)']
  result=subprocess.run(args,capture_output=True,text=True)
  assert report.exists(),(mode,result.stderr)
  import xml.etree.ElementTree as ET
  doc=ET.parse(report)
  cases=list(doc.iter('testcase'))
  assert len(cases)==1,(mode,len(cases))
  expected='failure' if mode=='failure-handler' else 'error' if mode!='ok' else None
  assert expected is None or cases[0].find(expected) is not None,(mode,report.read_text())
  print(mode,'OK')
 # Plusieurs fragments d'une suite et deux résultats homonymes doivent
 # rester présents, dans un ordre XML stable, sans trier les données du run.
 report=Path(t)/'sorted.xml'
 records='(("Zulu" 0.5 ((:ok "Zulu" "a" nil 0.5))) ("Alpha" 0.9 ((:fail "Alpha" "z" "assertion" 0.2) (:ok "Alpha" "a" nil 0.3) (:error "Alpha" "a" "erreur" 0.4))) ("Zulu" 0.2 ((:ok "Zulu" "b" nil 0.1) (:ok "Zulu" "b" nil 0.1))))'
 args=[os.environ.get('CLAUTOLISP_TEST_BIN') or shutil.which('clautolisp') or 'clautolisp','-norc','--host','cador','--dialect','bricscad-v26','-l',chemin_moteur(r/'autolisp-test/test-framework.lsp'),'-x',f"(setq *t:junit-suites* '{records} original *t:junit-suites*)",'-x',f'(t:junit-write "{chemin_moteur(report)}")','-x','(if (equal original *t:junit-suites*) (princ "ORDER-UNCHANGED") (princ "ORDER-MODIFIED"))','-x','(quit)']
 result=subprocess.run(args,capture_output=True,text=True)
 assert 'ORDER-UNCHANGED' in result.stdout,result.stderr
 root=ET.parse(report).getroot()
 assert [s.get('name') for s in root]==['Alpha','Zulu'],report.read_text()
 assert [[c.get('name') for c in s] for s in root]==[['a','a','z'],['a','b','b']],report.read_text()
 assert [c.tag for c in list(root[0])[0]]==[]
 assert list(root[0])[1].find('error') is not None
 assert root.get('tests')=='6' and root.get('failures')=='1' and root.get('errors')=='1'
 assert abs(float(root.get('time'))-1.6)<0.001
 print('sorted-suites-cases-preserve-duplicates OK')
