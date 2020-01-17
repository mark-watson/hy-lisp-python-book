# Why Lisp?

Now that we have learned the basics of the Hy Lisp language in the last chapter, I would like to move our conversation to a broader question of why we would want to use Lisp. I want to start with my personal history of why I turned to Lisp languages in the late 1970s for almost all of my creative and research oriented development and later transitioned to also using Lisp languages in production.

## I hated the Waterfall Method in the 1970s but Learned to Love a Bottom-Up Programming Style

I graduated UCSB in the mid 1970s with a degree in Physics and took a job as a scientific programmer in the 100% employee owned company SAIC. My manager had a PhD in Computer Science and our team and the organization we were in used what is known as the waterfall method where systems were designed carefully from the top down, carefully planned mostly in their entirety, and then coded up. We, and the whole industry I would guess, wasted a lot of time with early planning and design work that had to be discarded or heavily modified after some experience implementing the system.

What would be better? I grew to love bottom-up programming. When I was given a new project I would start by writing and testing small procedures for low level operations, things I was sure I would need. I then aggregated the functionality into higher levels of control logic, access to data, etc. Finally I would write the high level application.

I mostly did this for a while in FORTRAN at SAIC and some Algol at Salk Institute (I consulted on Saturdays at Salk Institute working on hooking up lab equipment to minicomputers).

I wanted a better programming language! I also wanted a more productive way to both do my job as a programmer and to make the best use of the few free hours a week that I had for my own research and learning about artificial intelligence (AI). I found my "better way" of development by adopting a bottom-up style that involves first writing low level libraires and utilities and then layering complete programs on top of well tested low level code.

## First Introduction to Lisp

In the late 1970s I discovered a Lisp implementation on my company's DECsystem-10 timesharing computer. I had heard of Lisp in reading Bertram Raphael's book "THE THINKING COMPUTER. Mind Inside Matter" and I learned Lisp during my lunch hours. After a few months of Lisp experience I received permission to teach an informal lunch time class to teach anyone working in my building who wantd to to learn Lisp on our DECsystem-10.

Lisp is the perfect language to support the type of bottom-up iterative programming style that I like.

## Commercial Product Development and Deployment Using Lisp

My company, SAIC, identified AI as an important technology in the early 1980s. Two friends at work (Bob Beyster who founded SAIC and Joe Walkush who was our corporate treasurer and who liked Lisp from his engineering studies at MIT) arranged for the company to buy me a hardware Lisp Machine, a Xerox 1108. I ported Charles Forgy's expert system development language OPS5 to run on InterLisp-D on the Xerox Lisp Machines and we successfully sold this as a product. When Coral Common Lisp was released for the Apple Macintosh in 1984, I switched my research and development to the Mac and released ExperOPS5 (which also sold well) and used Common Lisp to write the first prototypes for SAIC's ANSim neural network library (I converted my code to C++ to productize it). We also continued to use Lisp for IR&D projects.

Even though I proceeded to use C++ for much of my development, as well as writing C++ books for McGraw-Hill and J. Riley publishers, Lisp remained my "thinking and research" language.

## How Macros Make Bottom-Up Programming Elegant

TBD

## Using Closures is Often a Good Alternative to Object Oriented Programming

TBD

