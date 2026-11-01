#!/usr/bin/env python3
"""Vérifie les rapports du chemin C:RUN-NAMED avec clautolisp --host cador.

Exécution : python3 autolisp-test/tests/test_native_junit.py
Le moteur clautolisp doit être disponible dans PATH. Les fichiers sont temporaires.
"""
from pathlib import Path
import subprocess, tempfile, shutil, os
r=Path(__file__).resolve().parents[2].as_posix()
with tempfile.TemporaryDirectory() as t:
 t=Path(t).resolve().as_posix()
 for mode in ('ok','missing-suite','missing-test','failure-handler','error-handler'):
  report=Path(t)/f'{mode}.xml'
  args=[os.environ.get('CLAUTOLISP_TEST_BIN') or shutil.which('clautolisp') or 'clautolisp','-norc','--host','cador','--dialect','bricscad-v26','-x',f'(setq *tu:repo-dir* "{t}" *outils-autolisp-root* "{r}")','-l',r+'/autolisp-test/test-runner.lsp','-x',f'(setenv "AUTOLISP_TEST_JUNIT" "{report.as_posix()}")','-x',"(setq *t:suites* (list (list \"native\" (list \"reussi\" '(lambda () T)))))"]
  if mode=='ok':expr='(C:RUN-NAMED "native" "reussi")'
  elif mode=='missing-suite':expr='(C:RUN-NAMED "absente" "reussi")'
  elif mode=='missing-test':expr='(C:RUN-NAMED "native" "absent")'
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
