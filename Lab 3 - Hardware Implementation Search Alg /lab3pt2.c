#include <stdio.h>
#include <stdlib.h>

int main(void){
	
	volatile unsigned short int * sdram = (unsigned short int *)0xC0000000;
	volatile int * startSig = (int *) 0xFF200010;
	volatile int * doneSig = (int *) 0xFF200000;
	
	int i,j, value;
	printf("Done signal before all of this: %d\n",*doneSig);
	printf("Start Signal before all of this: %d\n",*startSig);
		for (i = 0; i < 10;i=i+1) {
			printf("Please enter a short integer\n");
			scanf("%d",&value);
			*(sdram+i) = value;
		}
		*startSig = 1;
		//printf("startSig value: %d\n",*startSig);
		//printf("Starting While Loop\n");
		while(*doneSig != 0);
		sdram = (unsigned short int *)0xC0000000;
		sdram++;
		printf("The min value was : %u\n", *sdram);
		sdram++;
		printf("The max value was : %u\n\n RESTARTING...\n\n", *sdram);
		sdram = (unsigned short int *)0xC0000000;

	return 0;
	
}