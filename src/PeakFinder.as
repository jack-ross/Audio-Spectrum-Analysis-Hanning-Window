package  {
	public class PeakFinder {
		
		/** Written By Jack Ross © 2012
		 * 
		 * This is a algorithm used to find the derivative of a 
		 * frequency vs dB graph. Finding the sign changes in the 
		 * derivative indicates a peak which inturn will be used
		 * to find fundemental and composite frequencies
		 * the peaks will then be compared to external note data 
		 * and check MIDI. For Chords, and now all notes, check if the first
		 * peak repeats each octave, and remove all those occurence then
		 * check for next peak
		 * 
		 */
		

		
		
		public function findPeak (mag:Vector.<Number>, freq:Vector.<Number> ):Array { 
			
			var arrayOfPeaks:Array = new Array; 						// array to hold all the peaks. storing just x coordinate
			var arrayOfPeaksAmplitude:Array = new Array; 						// array to hold all the peaks' amplitude. storing just y coordinate
			//trace("new array "+mag.length);
			for (var i:Number = 1; i < mag.length - 1; i++) {
				
				if(mag[i] > -40) {
				//trace("finding slope " + i);
				var leftHandPoint:Number = mag[i - 1]; 			// point just to the left of the point to be tested
				var rightHandPoint:Number = mag[i + 1];			// point just to the right of the point to be tested
				var centerPoint:Number = mag[i];
				
				//trace(centerPoint);
				
				var leftHandSlope:Number  = centerPoint - leftHandPoint;	// slope up to the point from the left
				var rightHandSlope:Number = rightHandPoint - centerPoint;	// slope up to the point from the right
				
				if (leftHandSlope > 0 && rightHandSlope < 0) {				// First Derrivative Test. Tests to see if slope to the
					arrayOfPeaks.push(freq[i]);								// left is positive and slope to right is negative indicating
					arrayOfPeaksAmplitude.push(Math.abs(mag[i]));						// store amplitude for peak
					//trace("point is "+i);									// a peak i.e a max or a zero in the first derivative
					//trace("freq of peak is  "+freq[i]);
					//trace("mag is"+mag[i]);
				}	
				
				}	
				else {
					//trace("mag is zero");
				}
			}

		getNote(arrayOfPeaks);
		//notePlayed(arrayOfPeaksAmplitude);

		return arrayOfPeaks;
		
		
	}
		
		
		public function getNote (arrayOfPeaks:Array):void {
			
			/**
			 * this finds the average of the peaks and if the average equals the first peak, 
			 * its only a single note, not a chord. if its a chord, well shit. 
						 * */

			var totalOfPeaks:Number = 0;
			for (var i:Number = 1; i < arrayOfPeaks.length; i++) {
				totalOfPeaks += arrayOfPeaks[i] - arrayOfPeaks[i-1];					// sum up difference of peaks
			}
			
			var averageOfPeaks:Number = totalOfPeaks/(arrayOfPeaks.length - 1);
			//trace("Average difference between peaks is "+averageOfPeaks);
			
						if (averageOfPeaks >= arrayOfPeaks[0] - 2 && averageOfPeaks <= arrayOfPeaks[0] + 2) {
				trace("note frequency is "+arrayOfPeaks[0]+" and average is "+averageOfPeaks);
			}
						
			
			for (var i = 1; i < arrayOfPeaks.length; i ++) {
				
			}
			for (var i = 1; i < arrayOfPeaks.length; i ++) {
				
				var selectedPeak:Number = arrayOfPeaks[i];
				var lowestPeak:Number = arrayOfPeaks[0];
				if (selectedPeak/2 <= (lowestPeak * 1.01) && selectedPeak >= (lowestPeak * 0.99)) {
					// first peak has a harmonic
					// remove first peak and save it has note
					
				}
			}

			//return;
		}
		
		
		
	}
}