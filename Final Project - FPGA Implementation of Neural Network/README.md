Overall Results
---------------------------------------
sdram_master (45X SpeedUp & Accuracy of 93).v contains the our final submission for the project. </br>
There are some extra files in here that are related to testing/previous designs (ie. different speed up designs)</br></br>
A lot of the issues we faced were due to timing issues that we did not have time to debug. Our group realized that we used too many muxes within a state, which imitated a combinational logic design. This could obviously be easily debugged if we had realized it earlier.</br>

Final Design consists of moving the entire neural network onto the FPGA fabric and performing the predictions for N amount of images on the FPGA. </br>

Some idea implementations we didn't have time to implement were:
- Encoding our data values
- Setting up multiple accumulators (performing the calculations for multiple nodes @ one time)
- Pushing our memory to it's limits (We used about 75% of the Onchip Memory; could have used all of it for weights)

Statistics
---------------------------------------
- Final Speed Up:
  - Between 46X to 47X faster on the FPGA vs. the C implementation on the ARM A9 processor
  - Original Processing Time: .2 seconds per image
  - Final Processing Time: .004s per image

- Accuracy: 
  - Before Acceleration: 97%
  - Post Acceleration: 91-93%

If there are any questions about the source files, please feel free to contact me.
