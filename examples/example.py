import os

# * class 

class Example:

# ** example class data 
    attr1 = 10
    
# ** example class functions
    def __init__(self,num):
        attr1 = num

# * function
def getter():
    x = Example(3)
    return x.attr1
    


# Local Variables:
# outline-regexp: "\\# \\(\\*+\\) \\(.*\\)$"
# End:
