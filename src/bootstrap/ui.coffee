emptyArray = []

class UI
    constructor: (@items) ->

    each: (callback) ->
        emptyArray.every.call @items, (el, idx) ->
            return callback.call(el, idx, el) isnt false
        return this

    addClass: (name) ->
        return this unless name?
        return this.each (idx) ->
            classList = this.className.split(/\s+/g)
            for klass in name.split(/\s+/g)
                classList.push(klass) if classList.indexOf(klass) == -1
            this.className = classList.join(" ")

    bind: (name, func) ->
        return this.each (idx) ->
            this.addEventListener(name, func)
            return

    removeClass: (name) ->
        return this.each (idx) ->
            unless name?
                this.className = ""
                return
            classList = this.className.split(/\s+/g)
            for klass in name.split(/\s+/g)
                index = classList.indexOf(klass)
                classList.splice(index) if index >= 0
            this.className = classList.join(" ")

    text: (text) ->
        if text?
            return this.each ->
                this.textContent = '' + text
        else
            return this[0].textContent if this.length > 0

    css: (property, value) -> 
        if (arguments.length < 2)
            element = @items[0]
            return unless element?
            computedStyle = getComputedStyle(element, '')
            return computedStyle.getPropertyValue(property)  

        if !value and value isnt 0
            this.each -> this.style.removeProperty(property)
        else
            this.each -> this.style.cssText += ';' + property + ":" + value

    attr: (name, value) ->
        if (arguments.length < 2)
            element = @items[0]
            return unless element?
            return element.getAttribute(name)

        if value?
            this.each -> this.setAttribute(name, value)
        else
            this.each -> this.removeAttribute(name)

    clone: ->
        return new UI(emptyArray.map.call(@items, (el) -> el.cloneNode(true)))

    append: (elements) ->
        return this.each -> 
            parent = this
            elements.each -> parent.appendChild(@cloneNode(true))
            return

    find: (selector) ->
        result = []
        this.each ->
            nodes = this.querySelectorAll(selector)
            emptyArray.every.call nodes, (el, idx) -> 
                result.push(el)
        return new UI(result)

$ = (param) ->
    if typeof param is "string"
        return new UI([document]).find(param)
    else
        return new UI(param)