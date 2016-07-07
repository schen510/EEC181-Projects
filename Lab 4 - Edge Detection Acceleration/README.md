
Edge Detection Acceleration Using FPGA
=========

Ran an accelerated edge detector. Used Sobel operator methods and pipelined each portion of the method to run per clock cyle.
Every clock cycle would run one portion of the sobel operator. Achieved a speed up of ~14X compared to original speed that was ran on
ARM A9 processor.

Results
======
FPGA Generated Image Below

![alt text][logox]
[logox]: https://github.com/schen510/EEC181-Projects/blob/master/Lab%204%20-%20Edge%20Detection%20Acceleration/FPGAgenerated.jpg "FPGA Generated Edge Detected Image"

Matlab Generated Image Below
![alt text][logo]
[logo]:https://github.com/schen510/EEC181-Projects/blob/master/Lab%204%20-%20Edge%20Detection%20Acceleration/trueMATLABimage.jpg "Matlab Generated Edge Detected Image"

