# Why Lisp?

Now that we have learned the basics of the Hy Lisp language in the last chapter, I would like to move our conversation to a broader question of why we would want to use Lisp. I want to start with my personal history of why I turned to Lisp languages in the late 1970s for almost all of my creative and research oriented development and later transitioned to also using Lisp languages in production.

## I Hated the Waterfall Method in the 1970s but Learned to Love a Bottom-Up Programming Style

I graduated UCSB in the mid 1970s with a degree in Physics and took a job as a scientific programmer in the 100% employee owned company SAIC. My manager had a PhD in Computer Science and our team and the organization we were in used what is known as the waterfall method where systems were designed carefully from the top down, carefully planned mostly in their entirety, and then coded up. We, and the whole industry I would guess, wasted a lot of time with early planning and design work that had to be discarded or heavily modified after some experience implementing the system.

What would be better? I grew to love bottom-up programming. When I was given a new project I would start by writing and testing small procedures for low level operations, things I was sure I would need. I then aggregated the functionality into higher levels of control logic, access to data, etc. Finally I would write the high level application.

I mostly did this for a while writing code in FORTRAN at SAIC and using Algol for weekend consulting work Salk Institute, working on hooking up lab equipment to minicomputers in Roger Guillemin's lab (he won a Nobel Prize during that time, which was exciting). Learning Algol, a very different language than FORTRAN, helped broaden my perspectives.

I wanted a better programming language! I also wanted a more productive way to do my job both as a programmer and to make the best use of the few free hours a week that I had for my own research and learning about artificial intelligence (AI). I found my "better way" of development by adopting a bottom-up style that involves first writing low level libraries and utilities and then layering complete programs on top of well tested low level code.

## First Introduction to Lisp

In the late 1970s I discovered a Lisp implementation on my company's DECsystem-10 timesharing computer. I had heard of Lisp in reading Bertram Raphael's book "THE THINKING COMPUTER. Mind Inside Matter" and I learned Lisp on my own time and then, during lunch hour, taught a one day a week class to anyone at work who wanted to learn Lisp. After a few months of Lisp experience I received permission to teach an informal lunch time class to teach anyone working in my building who wanted to to learn Lisp on our DECsystem-10.

Lisp is the perfect language to support the type of bottom-up iterative programming style that I like.

## Commercial Product Development and Deployment Using Lisp

My company, SAIC, identified AI as an important technology in the early 1980s. Two friends at work (Bob Beyster who founded SAIC and Joe Walkush who was our corporate treasurer and who liked Lisp from his engineering studies at MIT) arranged for the company to buy a hardware Lisp Machine, a Xerox 1108 for me. I ported Charles Forgy's expert system development language OPS5 to run on InterLisp-D on the Xerox Lisp Machines and we successfully sold this as a product. When Coral Common Lisp was released for the Apple Macintosh in 1984, I switched my research and development to the Mac and released ExperOPS5, which also sold well, and used Common Lisp to write the first prototypes for SAIC's ANSim neural network library. I converted my code to C++ to productize it. We also continued to use Lisp for IR&D projects and while working on the DARPA NMRD project.

Even though I proceeded to use C++ for much of my development, as well as writing C++ books for McGraw-Hill and J. Riley publishers, Lisp remained my "thinking and research" language.

## Hy Macros Let You Extend the Hy Language in Your Programs

In my work I seldom use macros since I mostly write application type programs. Macros are useful for extending the syntax allowed for programs written in Lisp languages.

My most common use of macros is flexibly handling arguments without evaluating them. In the following example I want to write a macro **all-to-string** that takes a list of objects that can include undefined symbols. For example, if the variable **x** is undefined, then trying to evaluate **(print x 1)** will throw an error like:

        NameError: name 'x' is not defined

The following listing shows my experiments in a Hy REPL to write the macro **all-to-string**:

{lang="hylang",linenos=on}
~~~~~~~~
$ hy
hy 0.17.0+108.g919a77e using CPython(default) 3.7.3 on Darwin
=> (list (map str ["a" 4]))
['a', '4']
=> (.join " " (list (map str ["a" 4])))
'a 4'
=> (defmacro foo2 [&rest x] x)
<function foo2 at 0x10b91b488>
=> (foo2 1 2 3)
[1, 2, 3]
=> (foo2 1 runpuppyrun 3)
Traceback (most recent call last):
  File "stdin-3241d1d4f129e0da87f331bfe8f9f7aba903073a", line 1, in <module>
    (foo2 1 runpuppyrun 3)
NameError: name 'runpuppyrun' is not defined
=> (defmacro all-to-string [&rest x] (.join " " (list (map str x))))
<function all-to-string at 0x10b91b158>
=> (all-to-string cater123 22)
'cater123 22'
=> (all-to-string the boy ran to get 1 new helmet)
'the boy ran to get 1 new helmet'
=> (all-to-string the boy "ran" to get 1 "new" helmet)
'the boy ran to get 1 new helmet'
=> 
~~~~~~~~

My first try in line 7 did not work, the macro just returning a function that echos the arguments but throws an error (line 50) when one of the arguments is a symbol with no definition. The second try on line 16 works as intended because we are mapping the function **str** (which coerces any argument into a string) over the argument list.

## Performing Bottom Up Development Inside a REPL is a Lifestyle Choice

It is my personal choice to prefer a bottom up style of coding, effectively extending the Hy (or other Lisp) language to look like something that looks custom designed and built to solve a specific problem. This is possible in Lisp languages because once a function or macro is defined, it is for our purposes part of the Hy language. If, for example, you are writing a web application that uses a database then I believe that it makes sense to first write low level functions to perform operations that you know you will need, for example, for creating and updating customer data from the database, utility functions used in a web application (which we cover in the next chapter), etc. For the rest of your application, you use these new low level functions as if they were built into the language.

When I need to write a new low-level function, I start in a REPL and define variables (with test values) for what the function arguments will be. I then write the code for the function one line at a time using these "arguments" in expressions that will later be copied to a Hy source file. Immediately seeing results in a REPL helps me catch mistakes early, often a misunderstanding of the type or values of intermediate calculations. This style of coding works for me and I hope you like it also.