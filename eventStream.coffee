#### Introduction

# In jQuery, Deferreds and Promises provide more of a one shot interface, useful for 
# ajax async calls and similar. But deferreds and pomises provide a progress callback. 
# This allows modelling of stream based computation in javascript. With some combinators,
# it should be possible to mitigate the callback spagetty one finds in javascript, while still
# use asynchronous calls. In essense, it should be possible to invert the control once more,
# and expose a declarive(ish) dataflow.
#
# Currently eventStream is a quick and dirty wrapper around jQuery Deferreds and Promises, with
# a few extras: 
# 
#  - `eventStream.on:: (event,selector) -> eventStream` turn the event on an element into a event source for the eventStream 
#  - `eventStream.on_:: (event,selector) -> eventStream` same as above, but the default behaviour of the event will be prevented 
#  - a few other event sources and transformers
#
# It is an unsafe(ish) interface, because the deferred is exposed, unlike jQuery's dfd.promise()
# Laziness, prevents from writing the 'proper' promise wrapper
#
# eventObserver is a small object, which implements an observer interface,
# partially inspired, by behaviours in FRP
#
# __TODO__ 
#
#  - DOM observers
#  - DOM sources 
#  - check if it could be useful to use and possibly integrate jsView
#  - D3 integration?
#  - add demos
#  - add tests, quickckeck would be cool
#  - will be intersting to try c
#  - resolve inconsistencies between sourses, constructors, ...  
# for example `on` vs `timer`
#
# There are quite a few question marks here, some of the answers will come from reading the Deferred's code
# others are yet more vague
#
# 1. What are the semantics of the deferred's, do they implement buffered  channels? 
# 2. What are the best, minimal combinators, should more be implemented?  
# 3. Unregistering callbacks? How can it be done using jQuery interface  
# 4. In the absense of proxies, using the old (current) dom monitoring can get very expensive, how to mitigate?  
# 5. more to come....

#### Usage and dependencies

# Depends on coffeescript, jQuery 1.7, and if you want the shiny doc docco.coffee  
#  
# There will be examples and demos at some point, hopefully soon

# we are inside a closure, just an alias will do
$ = jQuery

#### Declarations

# eventStream is an object type, which inherits from jQuery.Deferred, extended
# with a number of useful methods, aiming to get closer to an FRP|arrows-like
# interface
eventStream = {}

# adopt the jQuery.Deferred as the protype object
eventStream.prototype = $.Deferred

#### Event Sources

# attach a timer as an event source to the stream  
# the _delay_ argument is time in miliseconds
# all arguments are optional  
# type = `eventStream.timer:: ( Number, eventStream, String) -> eventStream`
eventStream::timer = (delay = 6000, stream = new eventStream(), type = "timer" ) ->
    clock = 0
    
    # a recursive procedure to run the timer clock
    timer = -> stream.notify
            type: type
            timer: delay
            clock: clock
            setTimeout timer, delay
            clock += 1
    #kickstart the timer
    setTimeout timer, delay
    stream

# attach an event source like click on selected elements, ...  
# type = `eventStream.on:: ( event, selector) -> eventStream`
eventStream::on = (event, selector) ->
    $(selector).on( event, (event) => this.notify event  )
    this

# attach an event source like click on selected elements, event is not propagated  
# type =`eventStream.on:: ( event, selector ) -> eventStream`
eventStream::on_ = (event, selector) ->
    $(selector).on( event, 
        (event) => 
            this.notify event 
            false 
        )
    this
     
# attach an ajax event source to the current eventStream
# the stream will be closed when the ajax call completes   
# type =  `eventStream.ajax:: a  -> eventStream`
#
# __TODO__ figure out a strategy for not closing the event stream,   
# maybe pack events (realised promises) in an onion object with a status field?
eventStream::ajax = ( args... ) -> 
    aj = $.ajax.apply( $, args );
    aj.done ( args... )     => this.resolve.apply( this, args )
    aj.fail ( args... )     => this.reject.apply( this, args )
    aj.progress ( args... ) => this.notify.apply( this, args )
    this

#### Stream Transformers

# Create a new event stream, listen on the current event stream, 
# apply the (d,r,n) functions to each value in the stream, 
# put the results into the new stream   
#  type = `eventStream.map:: ( a->b, a->b, a->b) -> eventStream`
eventStream::map = ( d, r, n ) -> 
    es = new $ES()
    this.done ( args... ) -> es.resolve d.apply( this, args )
    this.fail ( args... ) -> es.reject  r.apply( this, args )
    this.progress ( args... ) -> es.notify n.apply( this, args )
    es

# Create a delayed event stream. Internally, the delay buffer is maintained by steTimeout.
# The delay argument is optional, the default is 6sec    
#  type = `eventStream.delay:: ( Integer ) -> eventStream`
eventStream::delay = ( d = 6000 ) -> 
    s = $new ES();
    
    # a timer callback, abstracting out the stream signal 
    timer = (cb, args...) => () => cb.apply( this, args )
    setTimeout timer , d
    
    # the set of callbacks matching the different stream events
    this.done ( args... ) ->  setTimeout timer(s.resolve, args), d
    this.fail ( args... ) ->  setTimeout timer(s.reject, args), d 
    this.progress ( args... ) -> setTimeout timer(s.notify, args), d 
    s

#### Observers

# returns an observer object  
# type = `eventStream.observer:: ( a->b, a->b, a->b) -> eventObserver`
eventStream::observer = ( d, r, n ) -> 
    new $EO().observe( this, d, r, n)

# eventObserver is a small object, which implements an observer interface,
# partially inspired, by behaviours in FRP  
# type = `eventObserver:: init -> eventObserver`
eventObserver = ( init ) ->
    this.current = init
    this

# get the current value   
# type  = `eventObserver.value:: () -> a`
eventObserver::value = () -> @current


# observe an event stream, using the same callback for done, fail, and progress
# the current value of the eventObserver is updated with the result of the callbacks
# type = `eventObserver.observe1:: (eventSource, (a->b)) -> eventObserver`
eventObserver::observe1 = ( es, f ) ->
    that = this
    cb = (args...) -> that.current = f.apply(this, args)
    es.then( cb, cb, cb )
    that
    
# observe an event stream, using done, fail, and progress callbacks
# the current value of the eventObserver is updated with the result of the callbacks
# type = `eventObserver.observe:: (eventSource, (a->b), (a->b), (a->b)) -> eventObserver`
eventObserver::observe = ( es, d, f, n ) ->
    that = this
    cb = (f) -> (args...) -> that.current = f.apply(this, args)
    es.then( cb(d), cb(f), cb(n) )
    that

this.$EO = this.eventObserver = eventObserver
this.$ES = this.eventStream = eventStream