/**
 * VCS-Lisp Machine debugger
 */

NullRef = 0;

Symbolic = function(ref, name) {

    var self = this;

    /**
     * The ref for a symbolic is its symbol lookup code
     * 
     * @returns 
     */
    this.ref = function() { return ref; }; 

    this.toString = function() {
        return name;
    };

};

Numeric = function(ref, word) {

    var self = this;

    this.ref = function() { return ref; };

    this.word = function() { return word; };

    this.value = function() {
        return ((((word >> 8) * 10) + ((0xf0 & word) >> 4)) * 10) + (0x0f & word);
    };

    this.toString = function() {
        return self.value().toString();
    };

};

Pair = function(ref, car, cdr) {

    var self = this;

    this.ref = function() { return ref; };

    this.head = function() { return car; };
    this.car = self.head;

    this.tail = function() { return cdr; };
    this.cdr = self.tail;

    this.toString = function() {
        let s = '(';
        let current = self;
        do {
            s += current.head().toString();
            current = current.tail();
            if (current === NullRef) break;
            s += ' ';
        } while (true);
        s += ')';
        return s;
    };

};

LispMachine = function (ram) {

    "use strict";

    var self = this;

    var CELL_TYPE_PREFIX_MASK = 0x8000;
    var CELL_TYPE_PAIR_PREFIX = 0x8000;
    var CELL_TYPE_DECIMAL_PREFIX = 0x0000;
   
    var REF_TYPE_PREFIX_MASK = 0xc0;
    var REF_TYPE_SYMBOL_PREFIX = 0xc0;
    var SYMBOL_INDEX_MASK = 0x3f;

    var SYMBOLS = [
        '',
        '*',
        '+',
        '-',
        '/',
        '%',
        '=',
        '>',
        '<',
        '&',
        '|',
        '!',
        'cons',
        'car',
        'cdr',
        'apply',
        'f',
        'g',
        'h',
        'beep',
        'swap',
        'position',
        'shape',
        'score',
        'jx',
        'kx',
        'cx',
        '\'',
        'if',
        'loop',
        'progn',
        '#',
        '0',
        '1',
        '2',
        '3',
        '4',
        '5',
        '6',
        '7',
        '8',
        '9',
        'a',
        'b',
        'c',
        'd',
    ];

    var _modes = {
        'calc': 0,
        'song': 1,
        'game': 2,
        'stax': 3,
    }

    var _registers = {
        'free': 0xc0,
        'repl': 0xc1, 
        'f': 0xc2, 
        'g': 0xc3,
        'h': 0xc4,
        'accumulator': 0xc5,
        'game_state': 0xc8,
        'repl_edit_sym': 0xe3,
    };

    var _functionNames = ['repl', 'f', 'g', 'h'];

    var head = function(cell) {
        return cell >> 8;
    };

    var tail = function(cell) {
        return cell & 0xff;
    };

    this.decodeRef = function(ref) {
        switch (ref & REF_TYPE_PREFIX_MASK) {
            case REF_TYPE_SYMBOL_PREFIX:
                var index = ref & SYMBOL_INDEX_MASK;
                var symbol = SYMBOLS[index];
                return new Symbolic(ref, symbol);
            case 0:
                return NullRef;
        };
        var cell = ram.readWord(ref);
        switch (cell & CELL_TYPE_PREFIX_MASK) {
            case CELL_TYPE_DECIMAL_PREFIX:
                return new Numeric(ref, cell);
            case CELL_TYPE_PAIR_PREFIX:
                var car = self.decodeRef(head(cell));
                var cdr = self.decodeRef(tail(cell));
                return new Pair(ref, car, cdr);
        };
    };

    this.freeRef = function(ref) {
        switch (ref & REF_TYPE_PREFIX_MASK) {
            case REF_TYPE_SYMBOL_PREFIX:
            case 0:
                return;
        };

        var freeRef = ram.read(_registers['free']);
        var cell = ram.readWord(ref);
        switch (cell & CELL_TYPE_PREFIX_MASK) {
            case CELL_TYPE_PAIR_PREFIX:
                self.freeRef(head(cell));
                self.freeRef(tail(cell));
        };
        ram.write(ref, 0);
        ram.write(ref + 1, freeRef);
        ram.write(_registers['free'], ref);
    }

    this.allocRef = function() {
        var freeRef = ram.read(_registers['free']);
        if (freeRef === 0) {
            throw new Exception('OOM');
        }
        var freeCell = ram.readWord(freeRef);
        ram.write(_registers['free'], tail(freeCell));
        return freeRef;
    }

    this.encodeExpression = function(exp) {
        if (exp instanceof Array) {
            if (exp.length === 0) {
                return NullRef;
            }
            var ref = self.allocRef();
            var car = self.encodeExpression(exp[0]);
            var cdr = self.encodeExpression(exp.slice(1));
            ram.write(ref, car === 0 ? 0 : car.ref());
            ram.write(ref + 1, cdr === 0 ? 0 : cdr.ref());
            var pair = new Pair(
                ref,
                car,
                cdr
            );
            return pair;
        } else if (typeof exp === 'string') {
            var ref = self.symbolRef(exp);
            return new Symbolic(ref, exp);
        } else if (typeof exp === 'number') {
            var ref = self.allocRef();
            var word = self.convertNumber(exp);
            ram.writeWord(ref, word);
            return new Numeric(ref, word);            
        } else {
            // TODO: throw?
            return NullRef;
        }
    }

    this.symbolRef = function(s) {
        var i = SYMBOLS.findIndex((value) => value === s);
        return i | REF_TYPE_SYMBOL_PREFIX;
    }

    this.convertNumber = function (n) {
        n = n % 1000;
        var h = Math.floor(n / 100);
        var d = Math.floor((n % 100) / 10);
        var u = n % 10;
        var word = (h << 8) + (d << 4) + u;
        return word;
    }

    this.decodeRegister = function (name) {
        var cellRef = ram.read(_registers[name]);
        return self.decodeRef(cellRef);
    };

    this.encodeRegister = function (name, expr) {
        var cellRef = this.encodeExpression(expr);
        ram.write(_registers[name], cellRef === 0 ? 0 : cellRef.ref());
    };

    this.freeRegister = function (name) {
        var cellRef = ram.read(_registers[name]);
        self.freeRef(cellRef);
        ram.write(_registers[name], 0);
    }

    this.accumulator = function () {
        return new Numeric(ram.readWord(_registers["accumulator"])).value();
    };

    this.recall = async function () {
        const snapshot = await ram.snapshot();
        const fxns = {};
        _functionNames.forEach( (name) => {
            const data = self.decodeRegister(name);
            fxns[name] = data;
        });
        return fxns;
    };

    this.store = async function(exprs) {
        await self.clear();
        _functionNames.forEach( (name) => {
            self.encodeRegister(name, exprs[name]);
        });
        await ram.restore(0x80, 0xc5);
        return await self.recall();
    }

    this.clear = async function() {
        var i = 128
        while (i < 196) {
            ram.write(i, 0);
            const cdr = i + 1;
            const cddr = cdr + 1;
            ram.write(cdr, cddr);
            i = cddr;
        }
        ram.write(195, 0);
        ram.write(_registers['free'], 128);        
        _functionNames.forEach( (name) => {
            ram.write(_registers[name], 0);
        })
        await ram.restore(0x80, 0xc5);
    };

    this.getEditSym = async function() {
        await ram.snapshot();
        const gs = ram.read(_registers['game_state']);
        if ((gs & 0x80) === 1 || (gs & 0x0f) === 0) {
            // not in editor
            return;
        }
        return ram.read(_registers['repl_edit_sym']);
    }

    this.setGameState = async function(state) {
        if (typeof state === 'string') {
            state = _modes[state];
        }
        if (typeof state !== 'number') {
            return;
        }
        const ref = _registers['game_state'];
        ram.write(ref, state << 4);
        // BUGBUG: safety protections
        // BUGBUG: init game data
        await ram.restore(ref, ref + 1);
    }

    this.eval = async function() {
        await ram.snapshot();
        const ref = _registers['game_state'];
        const currentState = ram.read(ref);
        // BUGBUG: safety protections
        ram.write(ref, currentState | 0x80);
        await ram.restore(ref, ref + 1);
    }

};

ConsoleRam = function(stellerator) {

    var self = this;
    var ram = new Array(128);

    this.snapshot = async function() {
        try {
            await stellerator.pause();
            for (i = 128; i < 256; i++) {
                ram[i & 0x7f] = await stellerator._emulationService.peek(i);
            }
        } finally {
            await stellerator.resume();
        }
        return ram;
    }

    this.restore = async function(from, to) {
        try {
            await stellerator.pause();
            from = from ?? 128;
            to = to ?? 256;
            for (i = from; i < to; i++) {
                await stellerator._emulationService.poke(i, ram[i & 0x7f]);
            }
        } finally {
            await stellerator.resume();
        }
        return ram;
    }

    this.read = function(address) {
        return ram[address & 0x7f]
    }

    this.write = function(address, value) {
        ram[address & 0x7f] = value & 0xff
    }

    this.readWord = function(address) {
        return (self.read(address) << 8) + self.read(address + 1);
    }

    this.writeWord = function(address, word) {
        self.write(address, word >> 8);
        self.write(address + 1, word & 0xff);
    }

};

LispParser = function() {

    "use strict";

    var self = this;

    const DOUBLEQUOTE = /^"$/;
    const WHITESPACE = /^\s+$/;
    const OPENCLOSE = /^[()]$/
    const COMMENT = /^;$/;
    const NUMBER = /^\d+$/;

    this.parse = function(s) {
        var tokens = self.tokenize(s);
        var root = [];
        var stack = [root];
        for (const token of tokens) {
            if ("(" === token) {
                var l = []
                stack[stack.length-1].push(l);
                stack.push(l);
            } else if (")" === token) {
                stack.pop();
            } else if (token.length > 1 && NUMBER.test(token)) {
                var n = Number(token);
                stack[stack.length-1].push(n);
            } else {
                stack[stack.length-1].push(token);
            }
        }
        return root[0];
    };
    
    this.tokenize = function*(s) {
        var token = "";
        for (let i = 0; i < s.length; i++) {
            var c = s.slice(i, i+1);

            if (DOUBLEQUOTE.test(c)) {
                if (token.length > 0) {
                    yield token;
                    token = "";
                }
                for (i++; i < s.length; i++) {
                    c = s.charAt(i);
                    if ("\\" === c) {
                        i++;
                    } else if (DOUBLEQUOTE.test(c)) {
                        break;
                    }
                }

            } else if (OPENCLOSE.test(c)) {
                // separate out ( )
                if (token.length > 0) {
                    yield token;
                    token = "";
                }
                yield c;

            } else if (WHITESPACE.test(c)) {
                // remove whitespace
                if (token.length > 0) {
                    yield token;
                    token = "";
                }

            } else if (COMMENT.test(c)) {
                // consume comment to end of line
                if (token.length > 0) {
                    yield token;
                    token = "";
                }
                for (i++; i < s.length; i++) {
                    c = s.charAt(i);
                    if ("\n" === c) {
                        break;
                    }
                }

            } else {
                token += c;

            }
        }
        if (token.length > 0) {
            yield token;
            token = "";
        }
    };

};

LispIde = function (lisp) {

    var self = this;

    this.project = "";
    this.functions = {
        repl: NullRef,
        f0: NullRef,
        f1: NullRef,
        f2: NullRef
    };

    this.openWindow = function(event, id) {

        // hide/show content
        // based on: https://www.w3schools.com/howto/howto_js_tabs.asp

        let classPrefix = event.currentTarget.className.split("_")[0];
        let contentClass = classPrefix + "_content";
        let linkClass = classPrefix + "_links";

        // hide links
        let tabcontent = document.getElementsByClassName(contentClass);
        for (let i = 0; i < tabcontent.length; i++) {
            tabcontent[i].classList.toggle("active", tabcontent[i].id == id);
        }

        // hide tabs
        let tablinks = document.getElementsByClassName(linkClass);
        for (let i = 0; i < tablinks.length; i++) {
            tablinks[i].classList.toggle("active", tablinks[i] == event.currentTarget);
        }

    };

    this.changeMode = async function(event, idx) {
        lisp.setGameState(idx);
    };

    this.eval = lisp.eval;

    this.recallMemory = async function() {
        const compiledFunctions = await lisp.recall();
        self.functions = compiledFunctions;
        self._updateEditors();
    };

    this.getEditSym = lisp.getEditSym;

    this.storeMemory = async function(register, data) {
        var parsedFunctions = self._parseFunctionExpressions();
        const compiledFunctions = await lisp.store(parsedFunctions);
        self.functions = compiledFunctions;
    };

    this.clearMemory = async function() {
        self._okcancel("Clear Memory?", async () => {
            await lisp.clear();
            this.recallMemory();    
        }, true);
    };

    this.saveProject = async function() {
        let filename = (self.project || 'vcs-lisp') + '.json';
        const data = await self._exportProjectJson();
        const pdata = encodeURIComponent(JSON.stringify(data));
        // execute download
        var element = document.createElement('a');
        element.setAttribute('href', 'data:text/plain;charset=utf-8,' + pdata);
        element.setAttribute('download', filename);
        element.style.visibility = 'hidden';
        document.body.appendChild(element);
        element.click();
        document.body.removeChild(element);
    };

    this.shareProject = async function() {
        const data = await self._exportProjectJson();
        const pdata = btoa(JSON.stringify(data));
        const href = location.href + '#' + pdata;
        navigator.clipboard.writeText(href);
        self._okcancel("Copied link to clipboard!", () => {}, false);
    };

    this.loadProject = async function(event) {
        const input = event.target;
        const reader = new FileReader();
        reader.addEventListener(
            "load",
            () => {
                self._bindProjectData(reader.result);
            },
            false,
        );
        reader.readAsDataURL(input.files[0]);
    };

    this._exportProjectJson = async function() {
        let data = {
            project: self.project,
            functions: {}
        };
        let ide = document.getElementById("ide")
        let tabcontent = ide.getElementsByClassName("ide_content");
        for (let i  = 0; i < tabcontent.length; i++) {
            let name = tabcontent[i].id;
            let textContent = tabcontent[i].textContent;
            data.functions[name] = textContent;
        }
        return data;
    };

    this._bindProjectData = async function(pdata) {
        var data;
        if (typeof pdata === 'object') {
            data = pdata;
        } else if (pdata.startsWith('data:')) {
            const encoded = pdata.split(/[;,]/)[2];
            data = JSON.parse(atob(encoded));
        } else if (pdata.startsWith('#')) {
            data = JSON.parse(decodeURIComponent(atob(pdata.slice(1, pdata.length))));
        } else {
            data = JSON.parse(atob(pdata));
        }
        self.project = data.project;
        const projectElement = document.getElementById("project")
        if (projectElement) {
            projectElement.textContent = self.project;
        }
        for (const [key, value] of Object.entries(data.functions)) {
            const tabcontent = document.getElementById(key);
            if (tabcontent) {
                tabcontent.textContent = value;
            }
        }
        await self.storeMemory();
        if (data.mode) {
            lisp.setGameState(data.mode);
        }
    }

    this._okcancel = async function(text, accept, yesNo) {
        let modal = document.getElementById("ide_dialog");
        document.getElementById("ide_dialog_body")?.replaceChildren(text);
        let closeModal = async function() {
            modal.classList.toggle('active', false)
        };
        let cancelButton = document.getElementById('ide_dialog_cancel');
        let okButton = document.getElementById('ide_dialog_ok');
        cancelButton.onclick = closeModal;
        cancelButton.classList.toggle("active", yesNo);
        okButton.classList.toggle("active", true);
        okButton.onclick = function() {
            closeModal();
            accept();
        };
        modal.classList.toggle('active', true);
    };

    /**
     * Get function expressions
     * @returns 
     */
    this._parseFunctionExpressions = function() {
        var exprs = {};
        var parser = new LispParser();
        let ide = document.getElementById("ide")
        let tabcontent = ide.getElementsByClassName("ide_content");
        for (let i  = 0; i < tabcontent.length; i++) {
            let name = tabcontent[i].id;
            let textContent = tabcontent[i].textContent;
            exprs[name] = parser.parse(textContent);
        }
        return exprs;
    }

    this._updateEditors = function() {
        let ide = document.getElementById("ide")
        let tabcontent = ide.getElementsByClassName("ide_content");
        for (let i  = 0; i < tabcontent.length; i++) {
            let data = self.functions[tabcontent[i].id];
            if (data) {
                tabcontent[i].textContent = data.toString();
            }
        }
    }

    this._bindExamples = async function(examples) {
        self.examples = examples;
        const examplesDropdown = document.getElementById("examples_dropdown");
        for (const [key, value] of Object.entries(examples)) {
            const item = document.createElement("div");
            item.onclick = () => { self.loadExample(key); };
            item.className = "menu_dropdown_item";
            item.textContent = value.name;
            examplesDropdown.appendChild(item);
        }

        window.onclick = function(event) {
            if (!event.target.matches("div.header_menu_item label")) {
                examplesDropdown.classList.toggle("active", false);
            }
        }

    };

    this.showExamples = async function(event) {
        let examplesDropdown = document.getElementById("examples_dropdown");
        examplesDropdown.classList.toggle("active", true);

    }

    this.loadExample = async function(key) {
        let examplesDropdown = document.getElementById("examples_dropdown");
        examplesDropdown.classList.toggle("active", false);
        const example = self.examples[key];
        self._bindProjectData(example);
    };



    // bind examples then load project
    var initEnv = fetch("assets/examples.json")
        .then((response) => response.json())
        .then((json) => self._bindExamples(json));
    if (location.hash) {
        // dropoff link
        initEnv.then(() => {
            window.setTimeout(() => {
                self._bindProjectData(location.hash);
            }, 1000);
        });
    };

};

lispInit = async function(stellerator) {
    const ram = new ConsoleRam(stellerator);
    const lisp = new LispMachine(ram);
    const ide = new LispIde(lisp);
    return ide;
};
