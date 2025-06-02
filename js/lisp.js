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

LispMachine = function (ram, stellerator, symbols) {

    "use strict";

    var self = this;

    var CELL_TYPE_PREFIX_MASK = 0x8000;
    var CELL_TYPE_PAIR_PREFIX = 0x8000;
    var CELL_TYPE_DECIMAL_PREFIX = 0x0000;
   
    var REF_TYPE_PREFIX_MASK = 0xc0;
    var REF_TYPE_SYMBOL_PREFIX = 0xc0;
    var SYMBOL_INDEX_MASK = 0x3f;

    var _modes = [
        'calc',
        'song',
        'stax',
        'game',
    ];

    var _registers = {
        'free': 0xc0,
        'repl': 0xc1, 
        'f': 0xc2, 
        'g': 0xc3,
        'h': 0xc4,
        'accumulator': 0xc5,
        'game_state': 0xc8,
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
                var symbol = symbols.get(index).name;
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
        var i = symbols.lookup(s).code;
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

    this.countFreeMem = async function() {
        var count = 0;
        var freeRef = ram.read(_registers['free']);
        while (freeRef !== 0) {
            var freeCell = ram.readWord(freeRef);
            freeRef = tail(freeCell);
            count++;
        }
        return count;
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

    this.symbols = symbols;


    this.getGameState = async function() {
        await ram.snapshot();
        const ref = _registers['game_state'];
        return ram.read(ref);
    }

    this.getGameMode = async function() {
        const currentState = await this.getGameState();
        const stateIndex = (currentState & 0x70) >> 4;
        return _modes[stateIndex];
    }

    this.setGameState = async function(state) {
        if (typeof state === 'string') {
            state = _modes.indexOf(state);
        }
        if (typeof state !== 'number') {
            return;
        }
        const ref = _registers['game_state'];
        ram.write(ref, state << 4);
        // BUGBUG: safety protections
        await ram.restore(ref, ref + 1);
        // execute a reset
        stellerator.getControlPanel().reset().toggle(true);
        window.setTimeout( () => {
            stellerator.getControlPanel().reset().toggle(false);
        }, 1000);
    }

    this.eval = async function() {
        await ram.snapshot();
        const ref = _registers['game_state'];
        const currentState = ram.read(ref);
        // BUGBUG: safety protections
        ram.write(ref, currentState | 0x80);
        await ram.restore(ref, ref + 1);
    }

    this.isClear = async function () {
        await ram.snapshot();
        const freeMem = await self.countFreeMem();
        return freeMem === 32;
    };

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

SymbolReference = function() {

    "use strict";

    var self = this;
    var refdata = {};
    var codes = {};

    this._bindSymbols = function (symbols) {
        // init
        for (const spec of symbols) {
            const data = {
                name: spec.name,
                code: spec.code,
                synonyms: spec.synonyms,
                src: spec.src,
            };
            if (typeof data.code === 'number') {
                codes[data.code] = data;
            }
            refdata[data.name] = data;
            for (const sym of data.synonyms) {
                refdata[sym] = data;
            }
            // image load
            let img = new Image();
            img.src = data.src;
            data.img = img;
        }
    };

    this.lookup = function (symbol) {
        return refdata[symbol?.toString()];
    }

    this.get = function (index) {
        return codes[index];
    }

    // initialize
    fetch('assets/symbols.json')
        .then( (res) => { return res.json(); })
        .then( (res) => { self._bindSymbols(res); });
};

LispVizualizer = function(canvas, symbols) {

    "use strict";

    var self = this;

    const pixelW = 4;
    const pixelH = 2;
    const fontW = 8 * pixelW;
    const fontH = 8 * pixelH;
    const cellW = 8 * pixelW;
    const cellH = 11 * pixelH;

    const layout = [
        ['repl', 'f', 'g', 'h'],
    ];

    var ctx;

    this.resize = function(w, h) {
        // set up canvas
        canvas.width = w;
        canvas.height = h;
        ctx = canvas.getContext("2d");
        ctx.fillStyle = 'white'
        // shut off pixelation
        ctx.msImageSmoothingEnabled = false;
        ctx.mozImageSmoothingEnabled = false;
        ctx.webkitImageSmoothingEnabled = false;
        ctx.imageSmoothingEnabled = false;
    };

    this.isComplexExpression = function (expr) {
        if (expr.length > 4) {
            return true;
        }
        for (const cell of expr) {
            if (cell instanceof Array) {
                return true;
            }
            if (typeof cell === 'number' && (cell > 9 || cell < 0)) {
                return true;
            }
        }
        return false;
    };

    this.drawCell = function(s, x, y, bw = 1) {
        if (bw) {
            ctx.beginPath();
            ctx.fillRect(x, y, cellW, pixelH);
            ctx.fillRect(x, y, pixelW, cellH);
            ctx.fillRect(x + cellW, y, pixelW, cellH);
            ctx.fillRect(x, y + cellH - pixelH, cellW, pixelH);
            ctx.stroke();    
        }
        const img = symbols.lookup(s)?.img;
        if (img) {
            ctx.drawImage(img, x + 2 * pixelW, y + 2 * pixelH, fontW, fontH);
        }
        return [cellW, cellH];
    };

    this.drawVertical = function (expr, x, y) {
        self.drawCell('cell', x, y)[0];
        x = x + cellW;
        var maxW = cellW;
        var totalH = 0;
        for (const cell of expr) {
            var [w, h] = self.drawExpression(cell, x, y);
            y = y + h;
            totalH = totalH + h;
            w = w + cellW;
            if (w > maxW) {
                maxW = w;
            }
        }
        self.drawCell('term', x, y, 0);
        totalH = totalH + cellH
        return [maxW, totalH];
    };

    this.drawHorizontal = function (expr, x, y) {
        var [totalW, maxH] = self.drawCell('cell', x, y);
        x = x + totalW;
        for (const cell of expr) {
            const [w, h] = self.drawCell(cell, x, y);
            x = x + w;
            totalW = totalW + w;
            if (h > maxH) {
                maxH = h;
            }
        }
        return [totalW, maxH];
    };

    this.drawNumber = function (expr, x, y) {
        self.drawCell('#', x, y);
        self.drawCell(Math.floor(expr / 100), x + cellW, y);
        self.drawCell(Math.floor((expr % 100) / 10), x + 2 * cellW, y);
        self.drawCell(Math.floor(expr % 10), x + 3 * cellW, y);
        return [4 * cellW, cellH];
    };

    this.drawExpression = function (expr, x, y) {

        if (!expr) {
            return [cellW, cellH];
        } else if (expr instanceof Array) {
            return self.isComplexExpression(expr) ?
                self.drawVertical(expr, x, y) : 
                self.drawHorizontal(expr, x, y);
        } else if (typeof expr === 'number') {
            return self.drawNumber(expr, x, y);
        }

        return self.drawCell(expr, x, y);
    };

    this.estimateSizeHorizontal = function (expr) {
        return [(expr.length + 1) * cellW, cellH];
    };

    this.estimateSizeVertical = function (expr) {
        var maxW = cellW;
        var maxH = 0;
        for (const cell of expr) {
            var [w, h] = self.estimateSizeExpression(cell);
            maxH = maxH + h;
            w = w + cellW;
            if (w > maxW) {
                maxW = w;
            }
        }
        maxH = maxH + cellH;
        return [maxW, maxH];
    }

    this.estimateSizeExpression = function (expr) {
        if (expr instanceof Array) {
            return self.isComplexExpression(expr) ?
                self.estimateSizeVertical(expr) : self.estimateSizeHorizontal(expr)
        } else if (typeof expr === 'number') {
            return [4 * cellW, cellH];
        }
        return [cellW, cellH];
    }

    this.drawExpressions = function (exprs) {
        // get layout size
        var maxW = 0, maxH = 0;
        for (const [name, expr] of Object.entries(exprs)) {
            var [w, h] = self.estimateSizeExpression(expr);
            h = h + cellH * 3 / 2;
            if (w > maxW) {
                maxW = w;
            }
            if (h > maxH) {
                maxH = h;
            }
        }

        this.resize((maxW + cellW) * 4, (maxH + cellH) * 1);
        
        // draw expressions
        var y = cellH / 2;
        for (const row of layout) {
            var x = cellW / 2;
            for (const col of row) {
                const expr = exprs[col];
                self.drawCell(col, x, y, 0);
                self.drawExpression(expr, x, y + 3 * cellH / 2);
                x = x + maxW + cellW;    
            };
            y = y + maxH + cellH;
        }
    };

    this.clearCanvas = function() {
        ctx.setTransform(1, 0, 0, 1, 0, 0);
        ctx.clearRect(0, 0, canvas.width, canvas.height);
    };

};

LispIde = function (lisp) {

    var self = this;

    this.project = "";
    this.functions = {
        repl: NullRef,
        f: NullRef,
        g: NullRef,
        h: NullRef
    };

    var _key_mappings_0 = [
        ['#', '\u2191', 'del'],
        ['\u2190', '', '\u2192'],
        ['', '\u2193', 'shift'],
        ['eval', 'expr', 'E/F/G/H'],
    ]

    var _key_shifts_1 = [
        [0, 0, 0, 0],
        [0x20, 0x20, 0x20, 0x20 - 11],
        [0x29, 0x1c - 4, 0x13 - 7, 0x0f - 9],
        [0x15, 0x15, 0x0d - 7, 0x2b - 10],
    ]

    var _key_mappings_game = [
        ['', 'up', ''],
        ['left', '', 'right'],
        ['', 'down', ''],
        ['', '', ''],
    ]

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
        lisp.setGameState(idx).then(

        )
    };

    this.help = async function(event) {
        window.open('https://github.com/DChristianson/vcs-lisp/wiki');
    };

    this.eval = lisp.eval;

    this.recallMemory = async function() {
        const compiledFunctions = await lisp.recall();
        self.functions = compiledFunctions;
        self._updateEditors();
    };

    this.updateKeyMaps = async function() {
        const keyMap0 = await this._getKeyMap0();
        const keyMap1 = await this._getKeyMap1();
        for (const [key, value] of Object.entries({...keyMap0, ...keyMap1})) {
            document.getElementById(key).textContent = value;
        }
    };

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

    this.countFreeMem = lisp.countFreeMem;

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
        let modal = document.getElementById("ide_share");
        let copy_url_button = document.getElementById('ide_share_copy_url');
        let copy_image_button = document.getElementById('ide_share_copy_image');

        let closeModal = async function() {
            modal.classList.toggle('active', false)
        };

        // get viz
        (async () => {
            const canvas = document.getElementById('ide_share_viz');
            const viz = new LispVizualizer(canvas, lisp.symbols);
            var exprs = self._parseFunctionExpressions();
            viz.drawExpressions(exprs);
            copy_image_button.onclick = async function(event) {
                canvas.toBlob(function(blob) { 
                    const item = new ClipboardItem({ "image/png": blob });
                    navigator.clipboard.write([item])
                        .then(() => {
                            self._okcancel("Copied image to clipboard!", () => {}, false);
                        });
                });
            }
        })();

        // get share URL
        (async () => {
            const data = await self._exportProjectJson();
            const pdata = btoa(JSON.stringify(data));
            const href = location.href + '#' + pdata;
            copy_url_button.onclick = async function(event) {
                navigator.clipboard.writeText(href)
                    .then(() => {
                        self._okcancel("Copied link to clipboard!", () => {}, false);
                    });
            }
        })();

        let closeButton = document.getElementById('ide_share_close');
        closeButton.onclick = closeModal;
        modal.classList.toggle('active', true);
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
        let mode = await lisp.getGameMode();
        if (mode) {
            data.mode = mode;
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
        for (const key of ['repl', 'f', 'g', 'h']) {
            const value = data.functions[key] ?? '';
            const tabcontent = document.getElementById(key);
            if (tabcontent) {
                tabcontent.textContent = value;
            }
        }
        await self.storeMemory();
        if (data.mode) {
            lisp.setGameState(data.mode);
        }
    };

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

    this._waitInitialized = async function(timeout, retries, func) {
        if (retries < 0) {
            throw new Exception('INIT');
        }
        window.setTimeout(async () => {
            if (await lisp.isClear()) {
                func();
            } else {
                self._waitInitialized(timeout, retries - 1, func);
            }    
        }, timeout);
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

    this._getKeyMap0 = async function () {
        const keyMap = {};
        for (let row = 0; row <= 3; row++) {
            for (let col = 0; col <= 2; col++) {
                const label = `keypad0r${row}c${col}`;
                keyMap[label] = _key_mappings_0[row][col];
            }
        }
        return keyMap;
    }

    this._getKeyMap1 = async function () {
        const gs = await lisp.getGameState();
        const keyMap = {};
        if (gs & 0x80) {
            // eval mode
            for (let row = 0; row <= 3; row++) {
                for (let col = 0; col <= 2; col++) {
                    const label = `keypad1r${row}c${col}`;
                    keyMap[label] = _key_mappings_game[row][col];
                }
            }
        } else {
            // repl mode
            const shiftMode = (gs & 0x0f) >> 1;
            for (let row = 0; row <= 3; row++) {
                for (let col = 0; col <= 2; col++) {
                    const label = `keypad1r${row}c${col}`;
                    keyMap[label] = this._lookupKey1(shiftMode, row, col).name;
                }
            }    
        }
        return keyMap;        
    }

    this._lookupKey1 = function (shiftMode, row, col) {
        const rowShifts = _key_shifts_1[shiftMode];
        const b = rowShifts[row];
        const p = b + (row * 3) + col + 1;
        return lisp.symbols.get(p);
    }

    this._keyPadSvg = async function () {
        // experimental and very sketchy: dump SVG of keypads to console
        const keys_1 = [];
        for (let row = 0; row <= 3; row++) {
            const rkeys = [];
            for (let col = 0; col <= 2; col++) {
                const keys = [];
                for (let shiftMode = 0; shiftMode <= 3; shiftMode++) {
                    keys.push(this._lookupKey1(shiftMode, row, col).src);    
                }
                rkeys.push(keys)
            }
            keys_1.push(rkeys);
        }

        const buttonRadius = 4.5;
        const colSpacingX = 7;
        const rowSpacingY = 7;
        const marginX = 5;
        const topMarginY = 30;
        const overlayWidth = 51;
        const overlayHeight = 95;
        const overlayRx = 5;
        const overlaySpacing = 10;
        const symbolDx = 4;
        const symbolDxSm = 3.25;

        const escapeXml = (unsafe) => {
            return unsafe.replace(/[<>&'"]/g, function (c) {
                switch (c) {
                    case '<': return '&lt;';
                    case '>': return '&gt;';
                    case '&': return '&amp;';
                    case '\'': return '&apos;';
                    case '"': return '&quot;';
                }
            });
        };

        const mmToPx = (x) => x * 3.7795;

        const onCircle = (x, y, r, a) => {
            return [ x + r * Math.cos(a),  y + r * Math.sin(a) ];
          }

        const arc = (x, y, r, s, e, w, c) => {
            x = mmToPx(x);
            y = mmToPx(y);
            r = mmToPx(r);
            w = mmToPx(w);
            const [ x0, y0 ] = onCircle(x, y, r, s);
            const [ x1, y1 ] = onCircle(x, y, r, e);
            path = `M ${x0} ${y0} ` +
                   `A ${r} ${r}, 0, 0, 1, ${x1} ${y1}`;
            return `    <path stroke="${c}" d="${path}" stroke-width="${w}"/>\n`;
        }
        const filter = (name, color) => {
            const [r, g, b] = color.slice(4, color.length - 1).split(',').map(parseFloat).map(x => x / 255);
            return `<filter id="${name}">
               <feColorMatrix
                 in="SourceGraphic"
                 type="matrix"
                 color-interpolation-filters="sRGB"
                 values="${r} 0 0 0 0
                         0 ${g} 0 0 0
                         0 0 ${b} 0 0
                         0 0 0 1 0" />
            </filter>`;
        };
        const renderPad = (name, keys) => {
            var fragment = `    <!-- Keypad ${name} -->\n`
            fragment += `    <rect x="0mm" y="0mm" width="${overlayWidth}mm" height="${overlayHeight}mm" rx="${overlayRx}mm" />\n`
            fragment += `    <text x="${overlayWidth / 2.0}mm" y="${(topMarginY - rowSpacingY)/ 2.0}mm" class="title"  text-anchor="middle" dominant-baseline="middle">VCS Lisp</text>\n`;
            fragment += `    <text x="${overlayWidth / 2.0}mm" y="${topMarginY - rowSpacingY}mm" class="title"  text-anchor="middle" dominant-baseline="bottom">${name}</text>\n`;
            var y = topMarginY;
            for (let row = 0; row <= 3; row++) {
                x = marginX;
                for (let col = 0; col <= 2; col++) {
                    const s = keys[row][col];
                    if (typeof s === 'string') {
                        const tx = x + buttonRadius - symbolDxSm / 2.0 + 0.5;
                        const ty = y - symbolDxSm;
                        const rx = x + 2.0 * buttonRadius + 0.5;
                        const ry = y + buttonRadius - symbolDxSm / 2.0;
                        const lx = x - symbolDxSm + 0.5;
                        const ly = ry;
                        const bx = tx;
                        const by = y + 2.0 * buttonRadius;
                        if (row == 1 && col == 1) {
                            fragment += `     <text x="${x + buttonRadius}mm" y="${y - rowSpacingY / 2.0}mm" text-anchor="middle" dominant-baseline="middle">\u2191</text>\n`;
                            fragment += `     <text x="${x - colSpacingX / 2.0}mm" y="${y + buttonRadius}mm" text-anchor="middle" dominant-baseline="middle">\u2190</text>\n`;
                            fragment += `     <text x="${x + buttonRadius * 2.0 + colSpacingX / 2.0}mm" y="${y + buttonRadius}mm" text-anchor="middle" dominant-baseline="middle">\u2192</text>\n`;
                            fragment += `     <text x="${x + buttonRadius}mm" y="${y + buttonRadius * 2.0 + rowSpacingY / 2.0}mm" text-anchor="middle" dominant-baseline="middle">\u2193</text>\n`;

                        } else if (row == 2 && col == 2) {
                            fragment += `     <image image-rendering="pixelated" filter="url(#filter0)" x="${tx - symbolDxSm}mm" y="${ty}mm" width="${symbolDxSm}mm" height="${symbolDxSm}mm" href="${this._lookupKey1(0, 0, 0).src}" />\n`;
                            fragment += `     <image image-rendering="pixelated" filter="url(#filter0)" x="${tx}mm" y="${ty}mm" width="${symbolDxSm}mm" height="${symbolDxSm}mm" href="${this._lookupKey1(0, 0, 1).src}" />\n`;
                            fragment += `     <image image-rendering="pixelated" filter="url(#filter0)" x="${tx + symbolDxSm}mm" y="${ty}mm" width="${symbolDxSm}mm" height="${symbolDxSm}mm" href="${this._lookupKey1(0, 0, 2).src}" />\n`;
                            fragment += `     <image image-rendering="pixelated" filter="url(#filter1)" x="${rx}mm" y="${ry - symbolDxSm}mm" width="${symbolDxSm}mm" height="${symbolDxSm}mm" href="${this._lookupKey1(1, 0, 0).src}" />\n`;
                            fragment += `     <image image-rendering="pixelated" filter="url(#filter1)" x="${rx}mm" y="${ry}mm" width="${symbolDxSm}mm" height="${symbolDxSm}mm" href="${this._lookupKey1(1, 0, 1).src}" />\n`;
                            fragment += `     <image image-rendering="pixelated" filter="url(#filter1)" x="${rx}mm" y="${ry + symbolDxSm}mm" width="${symbolDxSm}mm" height="${symbolDxSm}mm" href="${this._lookupKey1(1, 0, 2).src}" />\n`;
                            fragment += `     <image image-rendering="pixelated" filter="url(#filter3)" x="${lx}mm" y="${ly - symbolDxSm}mm" width="${symbolDxSm}mm" height="${symbolDxSm}mm" href="${this._lookupKey1(3, 0, 0).src}" />\n`;
                            fragment += `     <image image-rendering="pixelated" filter="url(#filter3)" x="${lx}mm" y="${ly}mm" width="${symbolDxSm}mm" height="${symbolDxSm}mm" href="${this._lookupKey1(3, 0, 1).src}" />\n`;
                            fragment += `     <image image-rendering="pixelated" filter="url(#filter3)" x="${lx}mm" y="${ly + symbolDxSm}mm" width="${symbolDxSm}mm" height="${symbolDxSm}mm" href="${this._lookupKey1(3, 0, 2).src}" />\n`;
                            fragment += `     <image image-rendering="pixelated" filter="url(#filter2)" x="${bx - symbolDxSm}mm" y="${by}mm" width="${symbolDxSm}mm" height="${symbolDxSm}mm" href="${this._lookupKey1(2, 0, 0).src}" />\n`;
                            fragment += `     <image image-rendering="pixelated" filter="url(#filter2)" x="${bx}mm" y="${by}mm" width="${symbolDxSm}mm" height="${symbolDxSm}mm" href="${this._lookupKey1(2, 0, 1).src}" />\n`;
                            fragment += `     <image image-rendering="pixelated" filter="url(#filter2)" x="${bx + symbolDxSm}mm" y="${by}mm" width="${symbolDxSm}mm" height="${symbolDxSm}mm" href="${this._lookupKey1(2, 0, 2).src}" />\n`;

                        } else if (row == 3 && col == 2) {
                            fragment += arc(x + buttonRadius, y + buttonRadius, buttonRadius + symbolDxSm / 2.0, Math.PI * .25, Math.PI * .75, symbolDxSm, g);
                            fragment += arc(x + buttonRadius, y + buttonRadius, buttonRadius + symbolDxSm / 2.0, Math.PI * .75, Math.PI * 1.25, symbolDxSm, h);
                            fragment += arc(x + buttonRadius, y + buttonRadius, buttonRadius + symbolDxSm / 2.0, Math.PI * 1.25, Math.PI * 1.75, symbolDxSm, e);
                            fragment += arc(x + buttonRadius, y + buttonRadius, buttonRadius + symbolDxSm / 2.0, Math.PI * 1.75, Math.PI * .25, symbolDxSm, f);
                            fragment += `     <image image-rendering="pixelated" x="${tx}mm" y="${ty}mm" width="${symbolDxSm}mm" height="${symbolDxSm}mm" href="${lisp.symbols.lookup('lambda').src}" />\n`;
                            fragment += `     <image image-rendering="pixelated" x="${rx}mm" y="${ry}mm" width="${symbolDxSm}mm" height="${symbolDxSm}mm" href="${lisp.symbols.get(16).src}" />\n`;
                            fragment += `     <image image-rendering="pixelated" x="${lx}mm" y="${ly}mm" width="${symbolDxSm}mm" height="${symbolDxSm}mm" href="${lisp.symbols.get(17).src}" />\n`;
                            fragment += `     <image image-rendering="pixelated" x="${bx}mm" y="${by}mm" width="${symbolDxSm}mm" height="${symbolDxSm}mm" href="${lisp.symbols.get(18).src}" />\n`;
                        } else if (s === '#') {
                            fragment += `     <image image-rendering="pixelated"  filter="url(#filter1)" x="${tx}mm" y="${y - rowSpacingY / 2.0 - symbolDx / 3.0}mm" width="${symbolDx}mm" height="${symbolDx}mm" href="${lisp.symbols.lookup('hash').src}" />\n`;
                        } else if (s === 'del') {
                            fragment += `     <image image-rendering="pixelated"  filter="url(#filter3)" x="${x + buttonRadius - symbolDx * .75}mm" y="${y - rowSpacingY / 2.0 - symbolDx / 1.5}mm" width="${symbolDx * 2}mm" height="${symbolDx * 2}mm" href="${lisp.symbols.lookup('null').src}" />\n`;
                        } else if (s === 'eval') {
                            fragment += `     <image image-rendering="pixelated"  filter="url(#filter0)" x="${x + buttonRadius - symbolDx / 2.0}mm" y="${y + buttonRadius * 2.0 + rowSpacingY / 2.0 - symbolDx / 2.0}mm" width="${symbolDx}mm" height="${symbolDx}mm" href="${lisp.symbols.lookup('lambda').src}" />\n`;
                        } else if (s === 'expr') {
                            fragment += `     <image image-rendering="pixelated"  filter="url(#filter2)" x="${x + buttonRadius - symbolDx / 2.0}mm" y="${y + buttonRadius * 2.0 + rowSpacingY / 2.0 - symbolDx / 2.0}mm" width="${symbolDx}mm" height="${symbolDx}mm" href="${lisp.symbols.lookup('cell').src}" />\n`;
                        }
                    } else if (typeof s === 'object') {
                        const rx = buttonRadius + symbolDx / 2.0 + 1;
                        for (let i = 0; i < s.length; i++) {
                            const [sx, sy] = onCircle(x + buttonRadius - symbolDx / 2.0, y + buttonRadius - symbolDx / 2.0, rx, Math.PI * (1.25 + i * .25));
                            const data = s[i];
                            fragment += `     <image image-rendering="pixelated"  filter="url(#filter${i})" x="${sx}mm" y="${sy}mm" width="${symbolDx}mm" height="${symbolDx}mm" href="${data}" />\n`;
                        }
                    }
                    fragment += `    <circle cx="${x + buttonRadius}mm" cy="${y + buttonRadius}mm" r="${buttonRadius}mm" />\n`
                    x += buttonRadius * 2.0 + colSpacingX;
                }
                y += buttonRadius * 2.0 + rowSpacingY;
            }
            return fragment
        }


        const e = 'rgb(85, 15, 201)';
        const f = 'rgb(0, 112, 12)';
        const g = 'rgb(3, 60, 214)';
        const h = 'rgb(152, 19, 0)';

        var svg = `<svg version="1.1" xmlns="http://www.w3.org/2000/svg" 
                      width="${overlayWidth * 2.0 + overlaySpacing}mm" 
                      height="${overlayHeight}mm"
                      fill="white" 
                      stroke="black"
                      stroke-width="0.5mm">\n`;   
        svg += `<style>
            .label {
                font:  13px sans-serif;
                stroke-width: 1px;
            }
            .title {
                font:  26px sans-serif;
                stroke-width: 1px;
            }
        </style>`;                   
        svg += `<defs>
            ${filter('filter0', e)}
            ${filter('filter1', f)}
            ${filter('filter2', g)}
            ${filter('filter3', h)}
            <filter id="filter4">
               <feColorMatrix
                 in="SourceGraphic"
                 type="matrix"
                 color-interpolation-filters="sRGB"
                 values="0 0 0 0 0
                         0 0 0 0 0
                         0 0 0 0 0
                         0 0 0 1 0" />
            </filter>
        </defs>`;
        svg += `  <g>\n`;
        svg += renderPad('L', _key_mappings_0);
        svg += `  </g>\n`;
        svg += `  <g transform="translate(${mmToPx(overlayWidth + overlaySpacing)} 0)">\n`
        svg += renderPad('R', keys_1);
        svg += `  </g>\n`
        svg += '</svg>\n';
        console.log(svg);
    }

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

    // bind examples and reference data then load project
    var initEnv = fetch("assets/examples.json")
        .then((response) => response.json())
        .then((json) => self._bindExamples(json));

    if (location.hash) {
        initEnv = initEnv.then(() => {
            self._waitInitialized(1000, 5, () => {
                self._bindProjectData(location.hash);
            });
        });
    }
    initEnv.then(() => {
        window.setTimeout(() => self.updateKeyMaps(), 1000);
    });
};

lispInit = async function(stellerator) {
    const symbols = new SymbolReference();
    const ram = new ConsoleRam(stellerator);
    const lisp = new LispMachine(ram, stellerator, symbols);
    const ide = new LispIde(lisp);
    return ide;
};
