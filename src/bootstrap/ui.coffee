emptyArray = []

class UI
    constructor: (selector, element) ->
        @items = (element ? document).querySelectorAll(selector)

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
            element = this[0]
            return unless element?
            computedStyle = getComputedStyle(element, '')
            return computedStyle.getPropertyValue(property)  

        if !value and value isnt 0
            this.each -> 
                this.style.removeProperty(property)
        else
            this.each ->
                this.style.cssText += ';' + property + ":" + value

$ = (selector) ->
    return new UI(selector)