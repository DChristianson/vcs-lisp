/**
 * VCS-Lisp Machine debugger
 */

Null = 0;

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
            if (current === Null) break;
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
        'f0',
        'f1',
        'f2',
        'beep',
        'stack',
        'p0',
        'p1',
        'ball',
        'j0',
        'j1',
        'apply',
        'quote',
        'hash',
        'if',
        'loop',
        'progn',
        ' ',
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
        's',
        'i',
        'cx0b',
        'cx1b',
        'cx01',
    ];

    var _registers = {
        'free': 0xc0,
        'repl': 0xc1, 
        'f0': 0xc2, 
        'f1': 0xc3,
        'f2': 0xc4,
        'accumulator': 0xc5
    };

    var _functionNames = ['repl', 'f0', 'f1', 'f2'];

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
                console.log(`symbol ${ref} ${symbol} ${index}`)
                return new Symbolic(ref, symbol);
            case 0:
                return Null;
        };
        var cell = ram.readWord(ref);
        switch (cell & CELL_TYPE_PREFIX_MASK) {
            case CELL_TYPE_DECIMAL_PREFIX:
                console.log(`numeric ${ref} ${cell}`)
                return new Numeric(ref, cell);
            case CELL_TYPE_PAIR_PREFIX:
                var car = self.decodeRef(head(cell));
                var cdr = self.decodeRef(tail(cell));
                return new Pair(ref, car, cdr);
        };
    };

    this.freeRef = function(ref) {
        var freeRef = ram.read(_registers['free']);
        var cell = ram.readWord(ref);
        switch (cell & CELL_TYPE_PREFIX_MASK) {
            case CELL_TYPE_PAIR_PREFIX:
                self.freeRef(head(cell));
            case CELL_TYPE_DECIMAL_PREFIX:
                self.freeRef(car(cell));
        };
        ram.write(ref, 0);
        ram.write(ref + 1, freeRef);
        ram.write(_registers['free'], ref);
    }

    this.allocRef = function() {
        var freeRef = ram.read(_registers['free']);
        var freeCell = ram.readWord(freeRef);
        ram.write(_registers['free'], tail(freeCell));
        return freeRef;
    }

    this.encodeExpression = function(exp) {
        if (exp instanceof Array) {
            if (exp.length == 0) {
                return Null;
            }
            var ref = self.allocRef();
            var car = self.encodeExpression(exp.head());
            var cdr = self.encodeExpression(exp.tail());
            ram.write(ref, car.ref());
            ram.write(ref + 1, cdr === 0 ? 0 : cdr.ref());
            var pair = new Pair(
                ref,
                car,
                cdr
            );
            return pair;
        } else if (exp instanceof String) {
            var ref = self.symbolRef(exp);
            return new Symbolic(ref, exp);
        } else if (exp instanceof Number) {
            var ref = self.allocRef();
            var word = self.convertNumber(exp);
            ram.writeWord(ref, word);
            return new Numeric(ref, word);            
        } else {
            // TODO: throw?
            return Null;
        }
    }

    this.symbolRef = function(s) {
        var i = SYMBOLS.findIndex(s);
        return i || REF_TYPE_SYMBOL_PREFIX;
    }

    this.convertNumber = function (n) {
        var h = (n / 100).trunc();
        var d = ((n % 100) / 10).trunc();
        var u = (n % 10).trunc();
        var word = (h << 8) + (d << 4) + u;
        return n;
    }

    this.decodeRegister = function (name) {
        var cellRef = ram.read(_registers[name]);
        return self.decodeRef(cellRef);
    };

    this.encodeRegister = function (name, expr) {
        var cellRef = this.encodeExpression(expr);
        ram.write(_registers[name], cellRef);
    };

    this.freeRegister = function (name) {
        var cellRef = ram.read(_registers[name]);
        self.freeRef(cellRef);
        raw.write(_registers[name], 0);
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
    }

    this.clear = async function() {
        _functionNames.forEach( (name) => {
            self.freeRegister(name);
        });
    };

};

ConsoleRam = function(stellerator) {

    var self = this;
    var ram = new Array(128);

    this.snapshot = async function() {
        for (i = 128; i < 256; i++) {
            ram[i & 0x7f] = await stellerator._emulationService.peek(i);
        }
        return ram;
    }

    this.restore = async function() {
        for (i = 128; i < 256; i++) {
            await stellerator._emulationService.poke(i, ram[i & 0x7f]);
        }
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
        self.write(address, word & 0xff);
    }

};

LispParser = function() {

    "use strict";

    var self = this;

    var DOUBLEQUOTE = /"/;
    var WHITESPACE = /\s/;
    var OPENCLOSE = /()/
    var COMMENT = /;/;
    var NUMBER = /\d+/;

    this.parse = function(s) {
        var tokens = self.tokenize(s);
        var root = [];
        var stack = [root];
        for (var token in tokens) {
            if ("(" === token) {
                var l = []
                stack[-1].append(l);
                stack.append(l);
            } else if (")" === token) {
                stack.pop();
            } else if (token.length > 1 && NUMBER.test(token)) {
                var n = float(token);
                stack[-1].append(n);
            } else {
                stack[-1].append(token);
            }
        }
        return root;
    };
    
    this.tokenize = function*(s) {
        var token = "";
        for (let i = 0; i < exp.length; i++) {
            
            var c = s.charAt(i);

            if (DOUBLEQUOTE.test(c)) {
                if (token.length > 0) {
                    yield token;
                    token = "";
                }
                for (i++; i < exp.length; i++) {
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
                for (i++; i < exp.length; i++) {
                    c = s.charAt(i);
                    if ("\n" === c) {
                        break;
                    }
                }

            } else {
                token.append(c);

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

    this.project = 'vcs_lisp';
    this.functions = {
        repl: Null,
        f0: Null,
        f1: Null,
        f2: Null
    };

    this.openWindow = function(event, id) {

        let classPrefix = event.currentTarget.className.split("_")[0];
        let contentClass = classPrefix + "_content";
        let linkClass = classPrefix + "_links";

        // Get all elements with class and hide them
        let tabcontent = document.getElementsByClassName(contentClass);
        for (let i = 0; i < tabcontent.length; i++) {
            tabcontent[i].style.display = "none";
        }

        // Get all elements with class="tablinks" and remove the class "active"
        let tablinks = document.getElementsByClassName(linkClass);
        for (let i = 0; i < tablinks.length; i++) {
            tablinks[i].className = tablinks[i].className.replace(" active", "");
        }

        // Show the current tab, and add an "active" class to the button that opened the tab
        let currenttab = document.getElementById(id);
        currenttab.style.display = "flex";
        event.currentTarget.className += " active";
    };

    this.changeMode = async function(event, idx) {
        // BUGBUG: implement
    };

    this.eval = async function() {
        // BUGBUG: implement
    };

    this.recallMemory = async function() {
        const compiledFunctions = await lisp.recall();
        self.functions = compiledFunctions;
        self._updateEditors();
    };

    this.storeMemory = async function(register, data) {
        var parsedFunctions = self._parseFunctionExpressions();
        await lisp.clear();
        await lisp.store(parsedFunctions);
        const compiledFunctions = await lisp.recall();
        self.functions = compiledFunctions;
    };

    this.clearMemory = async function() {
        self._okcancel("Clear Memory?", async () => {
            await lisp.clear();
            this.recallMemory();    
        });
    };

    this.saveProject = async function() {
        let filename = self.project + '.js';
        let data = {
            project: self.project,
            editors: {}
        };
        let ide = document.getElementById("ide")
        let tabcontent = ide.getElementsByClassName("ide_content");
        for (let i  = 0; i < tabcontent.length; i++) {
            let name = tabcontent[i].id;
            let textContent = tabcontent[i].textContent;
            data.editors[name] = textContent;
        }
        // execute download
        var element = document.createElement('a');
        element.setAttribute('href', 'data:text/plain;charset=utf-8,' + encodeURIComponent(JSON.stringify(data)));
        element.setAttribute('download', filename);
        element.style.visibility = 'hidden';
        document.body.appendChild(element);
        element.click();
        document.body.removeChild(element);
    };

    this.loadProject = async function(event) {
        var input = event.target;
        var reader = new FileReader();
        reader.onload = function(){
            console.log(reader.result);
        };
        reader.readAsDataURL(input.files[0]);
    };

    this._okcancel = async function(text, accept) {
        let modal = document.getElementById("ide_dialog");
        modal.getElementsByClassName("modal-body")?.[0].replaceChildren(text);
        let closeModal = async function() {
            modal.style.display = 'none';
        };
        let cancelButton = document.createElement('button');
        cancelButton.onclick = closeModal;
        let okButton = document.createElement('button');
        okButton.onclick = function() {
            closeModal();
            accept();
        };
        modal.getElementsByClassName("modal-footer")?.[0].replaceChildren(
            okButton,
            cancelButton
        )
        modal.style.display = 'block';
    };

    /**
     * Get function expressions
     * @returns 
     */
    this._parseFunctionExpressions = function() {
        var exprs = {};
        var parser = LispParser();
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

};

lispInit = async function(stellerator) {
    const ram = new ConsoleRam(stellerator);
    const lisp = new LispMachine(ram);
    const ide = new LispIde(lisp);
    return ide;
};
