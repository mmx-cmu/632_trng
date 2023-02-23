from bisect import bisect_left
from primePy import primes
b = primes.first (3000)

def take_closest(myList, myNumber):
    """
    Assumes myList is sorted. Returns closest value to myNumber.

    If two numbers are equally close, return the smallest number.
    """
    pos = bisect_left(myList, myNumber)
    if pos == 0:
        return myList[0]
    if pos == len(myList):
        return myList[-1]
    before = myList[pos - 1]
    after = myList[pos]
    if after - myNumber < myNumber - before:
        return after
    else:
        return before
        
listnumdiv = [5,10,15,20,25,30,35,40,45,50]
#listbasesmallnum = [5,7,9,11,13,17,30,50,70,100,200,300,400,500,600,700]
#for y in listbasesmallnum:
outsidecounter = 0


print('\talways_comb case (fast_conf)')
for fast_prime_ind in range (3, 19):
# for y in range(200, 800,50):
    #a = take_closest(b, 50*y)
    a = b[fast_prime_ind]
    #print(f'finding prime for basenum {y} - nearest is {a}')
    print(f'\t\t5\'d{outsidecounter}: begin \n\t\t\tfast_loop_len = 7\'d{a};\n\t\t\tcase(slow_conf)')
    insidecounter = 0
    for x in listnumdiv:
        d = take_closest(b, a*x)
        print(f'\t\t\t\t4\'d{insidecounter}: slow_loop_len = 13\'d{d};')
        insidecounter +=1
    print('\t\t\t\tdefault: slow_loop_len = \'X;')
    print(f'\t\t\tendcase\n\t\tend')
    outsidecounter +=1
print('\t\tdefault: begin \n fast_loop_len = \'X slow_loop_len = \'X \n end;')
print('\tendcase')
print('endmodule')
