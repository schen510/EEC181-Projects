static inline unsigned int getCycles ()
{
	unsigned int cycleCount;
	// Read CCNT register
	asm volatile ("MRC p15, 0, %0, c9, c13, 0\t\n": "=r"(cycleCount));
	return cycleCount;
}
static inline void initCounters ()
{
	// Enable user access to performance counter
	asm volatile ("MCR p15, 0, %0, C9, C14, 0\t\n" :: "r"(1));
	// Reset all counters to zero
	int MCRP15ResetAll = 23;
	asm volatile ("MCR p15, 0, %0, c9, c12, 0\t\n" :: "r"(MCRP15ResetAll));
	// Enable all counters:
	asm volatile ("MCR p15, 0, %0, c9, c12, 1\t\n" :: "r"(0x8000000f));
	// Disable counter interrupts
	asm volatile ("MCR p15, 0, %0, C9, C14, 2\t\n" :: "r"(0x8000000f));
	// Clear overflows:
	asm volatile ("MCR p15, 0, %0, c9, c12, 3\t\n" :: "r"(0x8000000f));
}


int main(void)
{
	volatile int * pushbptr = (int *) 0xFF204000;
	volatile int * jtag_uartptr = (int *) 0xFF204010;
	volatile int * memoryptr = (int *) 0xFF200000;
	volatile int * reg32ptr = (int *) 0xFF204018;
	
	volatile int * FPGASDRAM = (int *) 0xC0000000;
	volatile int * FPGAOnChip = (int *) 0xC4000000;
	volatile int * HPSDDR3 = (int *) 0x0010000;
	volatile int * HPSOnChip = (int *) 0xFFFF0000;
	
	int num = 0, choice = 0, i = 0;
	initCounters ();
	unsigned int time = 0;
	while(1)
	{
		/*
		*reg32ptr = 0x04;
		*/
		//Part 1
		/*
		printf("Enter a 32-bit integer: ");
		scanf("%d", &num);
		*reg32ptr = num;
		*/
		
		//Part 2
		printf("FPGA-OnChip (1) , FPGASDRAM (2), HPS_DDR3(3), HPSOnChip(4): ");
		scanf("%d", &choice);
		if (choice == 1)
		{
			num = 0;
			time = getCycles();
			//writing to memory location
			for(i = 0; i < 4095; i++)
			{
				*(FPGAOnChip+i) = num++;
			}
			
			time = getCycles() - time;
			printf ("Elapsed Time(Writing): %d cycles\n", time);
			
			num = 0;
			time = getCycles();
			//Read Memory location and compare
			for(i = 0; i < 4095; i++)
			{
				if(*(FPGAOnChip+i)!= num)
					printf("wrong.");
				num = num + 1;
			}
			time = getCycles() - time;
			printf ("Elapsed Time(Reading): %d cycles\n", time);
		}
		else if (choice == 2)
		{
			num = 0;
			time = getCycles();
			//writing to memory location
			for(i = 0; i < 4095; i++)
			{
				*(FPGASDRAM+i) = num++;
			}
			time = getCycles() - time;
			printf ("Elapsed Time(Writing): %d cycles\n", time);
			
			num = 0;
			time = getCycles();
			//Read Memory location and compare
			for(i = 0; i < 4095; i++)
			{
				if(*(FPGASDRAM+i)!= num)
					printf("wrong.");
				num = num + 1;
			}
			time = getCycles() - time;
			printf ("Elapsed Time(Reading): %d cycles\n", time);
		}
		else if (choice == 5)
		{
			num = 0;
			time = getCycles();
			for(i = 0; i < 1000; i++)
			{
				*(HPSDDR3+i) = num++;
			}
			time = getCycles() - time;
			printf ("Elapsed Time(Writing): %d cycles\n", time);
			
			num = 0;
			time = getCycles();
			//Read Memory location and compare
			for(i = 0; i < 1000; i++)
			{
				if(*(HPSDDR3+i)!= num)
					printf("wrong.");
				num = num + 1;
			}
			time = getCycles() - time;
			printf ("Elapsed Time(Reading): %d cycles\n", time);
			
		}
		else if (choice == 4)
		{
			num = 0;
			time = getCycles();
			for(i = 0; i < 4095; i++)
			{
				*(HPSOnChip+i) = num++;
			}
			time = getCycles() - time;
			printf ("Elapsed Time(Writing): %d cycles\n", time);
			
			num = 0;
			time = getCycles();
			//Read Memory location and compare
			for(i = 0; i < 4095; i++)
			{
				if(*(HPSOnChip+i)!= num)
					printf("wrong.");
				num = num + 1;
			}
			time = getCycles() - time;
			printf ("Elapsed Time(Writing): %d cycles\n", time);
		}
		else
		{
			printf("Restart Program. Bad Input");
			return 0;
		}
	}
}
