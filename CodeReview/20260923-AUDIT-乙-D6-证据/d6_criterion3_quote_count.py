import subprocess, sys, json
sys.stdout.reconfigure(encoding='utf-8')

FILES = [
 'Examples/MultiLanguageDemo/MainForm.pas',
 'Tests/Acceptance/AcceptanceRunner.pas',
 'Tests/TestLLMClient.dpr',
 'Tools/LogAnalyzer/LogAnalyzer.MainForm.pas',
 'Tests/Acceptance/AcceptanceMain.pas',
 'Tools/LogAnalyzer/LogAnalyzer.dpr',
 'Tests/Acceptance/AcceptanceReport.pas',
 'Tests/Acceptance/DeepBaseAcceptanceTest.dpr',
]
BASE = '47dc031'

def blob(path, rev):
    return subprocess.run(['git','show',f'{rev}:{path}'],capture_output=True).stdout

def count(blob_bytes, seq):
    # count non-overlapping occurrences of byte seq
    n=0; i=0
    while True:
        j=blob_bytes.find(seq,i)
        if j<0: break
        n+=1; i=j+len(seq)
    return n

tot_q_before=tot_q_after=0
print('%-52s %8s %8s %8s %8s %8s' % ('file','q_before','q_after','dq_b','dq_a','empty_b'))
for f in FILES:
    b = blob(f,BASE); a = blob(f,'HEAD')
    qb = count(b,b"'"); qa = count(a,b"'")
    # doubled-quote escape '' (Delphi escaped quote inside string)
    db = count(b,b"''"); da = count(a,b"''")
    # empty string literal ''  -> same bytes as doubled quote in Delphi; count as occurrences of  ''  used as literal
    tot_q_before+=qb; tot_q_after+=qa
    print('%-52s %8d %8d %8d %8d' % (f,qb,qa,db,da))
print('TOTAL 单引号字节数 before=%d after=%d delta=%+d' % (tot_q_before,tot_q_after,tot_q_after-tot_q_before))
print()
print('说明：after>before 是被吞右引号回来的直接计量；本单未新增任何 #39/#+十进制转义写法。')
for f in FILES:
    a = blob(f,'HEAD')
    n_esc = count(a,b"#$")
    print('%-52s #%d转义出现=%d' % (f,39,n_esc))
