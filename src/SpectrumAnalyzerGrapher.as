package  
{
	import __AS3__.vec.Vector;
	
	import flash.display.Sprite;
	import flash.events.*;
	import flash.media.Microphone;
	import flash.text.*;
	import flash.utils.*;
	import flash.utils.getTimer;
	
	import flashx.textLayout.formats.BackgroundColor;
	
	import mx.utils.NameUtil;
	
	/**
	 * A real-time spectrum analyzer.
	 * 
	 * Released under the MIT License
	 *
	 * Copyright (c) 2010 Gerald T. Beauregard
	 *
	 * Permission is hereby granted, free of charge, to any person obtaining a copy
	 * of this software and associated documentation files (the "Software"), to
	 * deal in the Software without restriction, including without limitation the
	 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
	 * sell copies of the Software, and to permit persons to whom the Software is
	 * furnished to do so, subject to the following conditions:
	 *
	 * The above copyright notice and this permission notice shall be included in
	 * all copies or substantial portions of the Software.
	 *
	 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
	 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
	 * IN THE SOFTWARE.
	 */
	
	[SWF(width='1150', height='800', frameRate='30', backgroundColor='0x000000')]
	public class SpectrumAnalyzerGrapher extends Sprite
	{
		private const SAMPLE_RATE:Number = 22050;	// Actual microphone sample rate (Hz)
		private const LOGN:uint = 13;				// Log2 FFT length
		private const N:uint = 1 << LOGN;			// FFT Length
		private const BUF_LEN:uint = N;				// Length of buffer for mic audio
		private const UPDATE_PERIOD:int = 5;		// Period of spectrum updates (ms)
		
		private var m_fft:FFT2;						// FFT object
		
		private var peakFinder:PeakFinder;			// peak finder object
		private var peaksXCoordinate:Array			// array of peaks. just X coordinate 
		
		// Run analysis to decipher time note is played
		private var currentMagnitudeArray:uint = new uint(0);
		private var notePlayedRunning:Boolean = new Boolean;
		
		// compare arrays for increase/played notes
		private var previousNoteArrayFreq:Array = new Array();
		private var previousNoteArrayAmpl:Array = new Array();
		private var currentNoteArrayFreq:Array  = new Array();
		private var currentNoteArrayAmpl:Array  = new Array();
		
		// store played notes in array to gather all music
		private var previousNotesPlayedFreq:Array  = new Array();
		private var previousNotesPlayedAmpl:Array  = new Array();
		private var previousNotesPlayedTime:Array  = new Array();
		
		// hanning window
		
		public var tPeak:TextField = new TextField();
		private var tForFF:TextField = new TextField();
		
		private var m_tempRe:Vector.<Number>;		// Temporary buffer - real part
		private var m_tempIm:Vector.<Number>;		// Temporary buffer - imaginary part
		private var m_mag:Vector.<Number>;			// Magnitudes (at each of the frequencies below)
		private var m_freq:Vector.<Number>;			// Frequencies (for each of the magnitudes above) 
		private var m_win:Vector.<Number>;			// Analysis window (Hanning)
		
		private var m_mic:Microphone;				// Microphone object
		private var m_writePos:uint = 0;			// Position to write new audio from mic
		private var m_buf:Vector.<Number> = null;	// Buffer for mic audio
		
		private var m_tickTextAdded:Boolean = false; 
		
		private var m_timer:Timer;					// Timer for updating spectrum
		
		private var objectColor:Number = 0x33FF00; // color of lines and labels 
		
		private var startTime:Number = new Number;
		
		/**
		 * start program and call other methods
		 */		
		
		public function SpectrumAnalyzerGrapher() {
			init(0);
		}
		public function init (micChosen:Number)
		{
			
			//start timer
			
			startTime = getTimer() * 0.001;
			
			var i:uint;
			
			// Set up the FFT
			m_fft = new FFT2();
			m_fft.init(LOGN);
			m_tempRe = new Vector.<Number>(N);
			m_tempIm = new Vector.<Number>(N);
			m_mag = new Vector.<Number>(N/2);
			//m_smoothMag = new Vector.<Number>(N/2);
			
			// Vector with frequencies for each bin number. Used 
			// in the graphing code (not in the analysis itself).			
			m_freq = new Vector.<Number>(N/2);
			for ( i = 0; i < N/2; i++ )
				m_freq[i] = i*SAMPLE_RATE/N;
			
			// Hanning analysis window
			m_win = new Vector.<Number>(N);
			for ( i = 0; i < N; i++ )
				m_win[i] = (4.0/N) * 0.5*(1-Math.cos(2*Math.PI*i/N));
			
			// Create a buffer for the input audio
			m_buf = new Vector.<Number>(BUF_LEN);
			for ( i = 0; i < BUF_LEN; i++ )
				m_buf[i] = 0.0;
			
			// Set up microphone input
			m_mic = Microphone.getMicrophone(micChosen);
			m_mic.gain = 100;
			//m_mic.setLoopBack(true);

			var allMicNames_array:Array = Microphone.names;
			
			trace("Microphone.names located these device(s):");
			
			for( i = 0; i < allMicNames_array.length; i++){
				trace("[" + i + "]: " + allMicNames_array[i]);
				
				var t:TextField = new TextField();
				t.text = allMicNames_array[i];
				t.width = 0;
				t.x = 80+ 100*i;
				t.y = 10;
				t.autoSize = TextFieldAutoSize.CENTER;
				
				// Color of Text
				var tfFormatter:TextFormat = new TextFormat();
				tfFormatter.color = objectColor;
				t.setTextFormat(tfFormatter);
				
				addChild(t);
			}

			tForFF.text = "First Peak is ";
			tForFF.width = 0;
			tForFF.x = 80+ 100*8;
			tForFF.y = 10;
			tForFF.autoSize = TextFieldAutoSize.CENTER;
			
			// Color of Text
			var tfFormatter:TextFormat = new TextFormat();
			tfFormatter.color = objectColor;
			tForFF.setTextFormat(tfFormatter);
			
			addChild(tForFF);
			
			
			m_mic.rate = SAMPLE_RATE/1000;		
			m_mic.setSilenceLevel(0.0);			// Have the mic run non-stop, regardless of the input level
			m_mic.addEventListener( SampleDataEvent.SAMPLE_DATA, onMicSampleData );
			
			// Set up a timer to do periodic updates of the spectrum		
			m_timer = new Timer(UPDATE_PERIOD);
			m_timer.addEventListener(TimerEvent.TIMER, updateSpectrum);
			m_timer.start();
		}
		
		/**
		 * Called whether new microphone input data is available. See this call
		 * above:
		 *    m_mic.addEventListener( SampleDataEvent.SAMPLE_DATA, onMicSampleData );
		 */
		private function onMicSampleData( event:SampleDataEvent ):void
		{
			// Get number of available input samples
			var len:uint = event.data.length/4;
			
			// Read the input data and stuff it into 
			// the circular buffer
			for ( var i:uint = 0; i < len; i++ )
			{
				m_buf[m_writePos] = event.data.readFloat();
				m_writePos = (m_writePos+1)%BUF_LEN;
			}
		}
		
		/**
		 * Called at regular intervals to update the spectrum
		 */
		private function updateSpectrum( event:Event ):void
		{
			// Copy data from circular microphone audio 
			// buffer into temporary buffer for FFT, while
			// applying Hanning window.
			var i:int;
			var pos:uint = m_writePos;
			for ( i = 0; i < N; i++ )
			{
				m_tempRe[i] = m_win[i]*m_buf[pos];
				pos = (pos+1)%BUF_LEN;
			}
			
			// Zero out the imaginary component
			for ( i = 0; i < N; i++ )
				m_tempIm[i] = 0.0;
			
			// Do FFT and get magnitude spectrum
			m_fft.run( m_tempRe, m_tempIm );
			for ( i = 0; i < N/2; i++ )
			{
				var re:Number = m_tempRe[i];
				var im:Number = m_tempIm[i];
				m_mag[i] = Math.sqrt(re*re + im*im);
			}
			
			// Convert to dB magnitude
			const SCALE:Number = 20/Math.LN10;		
			for ( i = 0; i < N/2; i++ )
			{
				// 20 log10(mag) => 20/ln(10) ln(mag)
				// Addition of MIN_VALUE prevents log from returning minus infinity if mag is zero
				//m_mag[i] = SCALE*Math.log( m_mag[i] + Number.MIN_VALUE );
			}
			
			//call note played
			notePlayed(m_mag, m_freq);
			
			// Draw the graph
			drawSpectrum( m_mag, m_freq );
				
		}
		
		private function notePlayed (mag:Vector.<Number>, freq:Vector.<Number> ):void {
			/**
			 * save first amplitude array as Array 1
			 * when second array is recieved check if average is greater than first array
			 * repeat into 3rd array then loop back to first array
			 * 
			 * When value switches from increasing to decreasing, the note reached a peak volume, thus
			 * indicating it was played at that time. Record the time for future use
			 * 
			 * if three peaks or more are increasing simultaneously, with an increase of >= x%, note was played
			 * use un-edited original array, with all 1024 peices to compare every frequency on change in amplitude
			 * 
			 */
			
			// time at start of this method
			
			var notesThatIncreasedFreqArray:Array = new Array();
			var notesThatIncreasedAmplArray:Array = new Array();
			
			//trace("note array length = "+freq.length);
			for (var i:Number = 0; i < mag.length; i++) {
				if (mag[i] > previousNoteArrayAmpl[i]*1.2 && mag[i] > .01) {
					// freq has greater amplitude then previously
					// add freq to Array of Increasing notes
					//trace("Ampl increase detected at "+freq[i] + " of amplitude " + mag[i])//" by amount "+mag[i]/previousNoteArrayAmpl[i]+ "%");
					notesThatIncreasedFreqArray.push(freq[i]);
					notesThatIncreasedAmplArray.push(mag[i]);
				}
				
			}
			
			if (notesThatIncreasedFreqArray.length >=3) {
				//trace("sending increasing peaks to test for harmonics");
				runIncreasingNotesDerivative(notesThatIncreasedAmplArray, notesThatIncreasedFreqArray);

			}
			switch (currentMagnitudeArray) {
				// for first time
				case 0:
					// used when program starts
					currentMagnitudeArray = 1;
					
					for (var iArray:Number = 0; iArray<freq.length; iArray++) {
						previousNoteArrayFreq.push(freq[iArray]);
						previousNoteArrayAmpl.push(mag[iArray]);
					}
					
					break;
				
				// loop 
				case 1:
					currentMagnitudeArray = 2;
					previousNoteArrayFreq.splice(0,previousNoteArrayFreq.length);
					previousNoteArrayAmpl.splice(0,previousNoteArrayAmpl.length);	
					
					for (var iArray:Number = 0; iArray<freq.length; iArray++) {
						previousNoteArrayFreq.push(freq[iArray]);
						previousNoteArrayAmpl.push(mag[iArray]);
					}
					break;
				
				case 2:
					currentMagnitudeArray = 3;
					previousNoteArrayFreq.splice(0,previousNoteArrayFreq.length);
					previousNoteArrayAmpl.splice(0,previousNoteArrayAmpl.length);
					
					for (var iArray:Number = 0; iArray<freq.length; iArray++) {
						previousNoteArrayFreq.push(freq[iArray]);
						previousNoteArrayAmpl.push(mag[iArray]);
					}					
					break;
				
				case 3:
					currentMagnitudeArray = 1;
					previousNoteArrayFreq.splice(0,previousNoteArrayFreq.length);
					previousNoteArrayAmpl.splice(0,previousNoteArrayAmpl.length);
					
					for (var iArray:Number = 0; iArray<freq.length; iArray++) {
						previousNoteArrayFreq.push(freq[iArray]);
						previousNoteArrayAmpl.push(mag[iArray]);
					}
					break;
			}			

			notePlayedRunning = false;
			
			// time at end of this method
			startTime = getTimer() * 0.001;
		}
		
		private function runIncreasingNotesDerivative(magOfPeaks:Array, freqOfPeaks:Array):void {
			
			//trace("Running derivative with freq array of length "+freqOfPeaks.length);
			
			var arrayOfPeaksFrequency:Array = new Array; 						// array to hold all the peaks. storing just x coordinate
			var arrayOfPeaksAmplitude:Array = new Array; 						// array to hold all the peaks' amplitude. storing just y coordinate
			
			
			for (var i:Number = 1; i < magOfPeaks.length - 1; i++) {
				
				// check if next freq is even possible, it must be >= to next fret
				// starts at a minumum addition of 7 b/c that is the difference between 5/6 fret on low E b/c that is where notes start repeating
				// replace 7 with dynamic value based on minimum distance(freq) between frets, so at higher freq it is > 2^(1/12) of previous note
				if (arrayOfPeaksFrequency.length == 0 || freqOfPeaks[i] > arrayOfPeaksFrequency[arrayOfPeaksFrequency.length-1] +7 
					&& freqOfPeaks[i] > (arrayOfPeaksFrequency[arrayOfPeaksFrequency.length-1]*1.059)) {
				
					if( freqOfPeaks[i] > 80 ) {	 											// minumum frequency/lowest note on guitar?
						
						
						var leftHandPointFreq:Number = freqOfPeaks[i - 1]; 					// point just to the left of the point to be tested
						var rightHandPointFreq:Number = freqOfPeaks[i + 1];					// point just to the right of the point to be tested
						var centerPointFreq:Number = freqOfPeaks[i];	
							
						var leftHandPointAmpl:Number = magOfPeaks[i - 1]; 					// point just to the left of the point to be tested
						var rightHandPointAmpl:Number = magOfPeaks[i + 1];					// point just to the right of the point to be tested
						var centerPointAmpl:Number = magOfPeaks[i];
						
						
						var leftHandSlope:Number  = centerPointAmpl - leftHandPointAmpl;	// slope up to the point from the left
						var rightHandSlope:Number = rightHandPointAmpl - centerPointAmpl;	// slope up to the point from the right
						
						// start from a break in continuity with decreasing slope, like landing on the other side of a jump at the peak
						if(leftHandPointFreq < centerPointFreq - 6 && rightHandSlope < 0) {
							arrayOfPeaksFrequency.push(freqOfPeaks[i]);						// store freq for peak
							arrayOfPeaksAmplitude.push(magOfPeaks[i]);						// store amplitude for peak
						}
						
						// end of continuous freq, with increasing slope, kinda like a cliff
						else if(rightHandPointFreq > centerPointFreq + 6 && leftHandSlope < 0) {
							arrayOfPeaksFrequency.push(freqOfPeaks[i]);						//  store freq for peak
							arrayOfPeaksAmplitude.push(magOfPeaks[i]);						// store amplitude for peak
						}	
						
						// derrivative 
						else if (leftHandSlope > 0 && rightHandSlope < 0) {			// First Derrivative Test. Tests to see if slope to the
							arrayOfPeaksFrequency.push(freqOfPeaks[i]);				// left is positive and slope to right is negative indicating local max
							arrayOfPeaksAmplitude.push(magOfPeaks[i]);				// store amplitude for peak
							//trace("freq of peak is  "+freqOfPeaks[i]);
						}	
					}	
				}
			}
			//trace("array of harmonics "+arrayOfPeaksFrequency);
			buildArrayOfHarmonics(arrayOfPeaksAmplitude,arrayOfPeaksFrequency);
			
		}
		
		private function buildArrayOfHarmonics (magOfPeaks:Array, freqOfPeaks:Array):void {
			
			var arrayOfNotesAndTime:Array = new Array(); 		// an array to store note,harmonics,time
			var arrayOfFF:Array = new Array();
			var arrayOfFFAmpl:Array = new Array();
			var noteHasHarmonics:Boolean = new Boolean(0);
			
			while(freqOfPeaks.length >=2) {
				
				var arrayOfHarmonics:Array = new Array();
				var arrayOfHarmonicsAmplitude:Array = new Array();
				var firstPeak:Number = freqOfPeaks[0];			// peak selected to start octaves
				var firstPeakAmpl:Number = magOfPeaks[0];		// Math.pow(10,-magOfPeaks[0]/20);	// amplitude of first peak in linear scale
				var lengthOfArray:Number = freqOfPeaks.length; 	// register max length to prep for harmonic multiples
				freqOfPeaks.splice(0,1); 						// remove firstPeak from Array
				magOfPeaks.splice(0,1); 						// remove firstPeak from Array of magnitudes
				arrayOfHarmonics.push(firstPeak);				// add firsteak to Array of Harmonics as first point
				arrayOfHarmonicsAmplitude.push(firstPeakAmpl);
				
				//trace("first Peak is "+firstPeak);
				
				noteHasHarmonics = false;						// set to false until harmonic is found


				// cycle through each peak to build array of harmonics for firstPeak
				outerLoop:
				for (var i:int = 0; i<freqOfPeaks.length; i++){
					
					var selectedPeak:Number = freqOfPeaks[i];		// peak chosen to be compared to firstPeak
					var selectedPeakAmp:Number = magOfPeaks[i];
					
					// cycle through multiples of firstPeak, 3x length to ensure 3rd octave is captured
				
					for (var i2:int = 2; i2<=lengthOfArray*3; i2++){
						
						// test if harmonic is a multiple of firstPeak
						// ** min distance between note at 80z is 2.81% of 83 Hz, but we use a larger error b/c notes arent played exactly next to each other at low end 
						if (selectedPeak < ((firstPeak*1.02)*i2) && selectedPeak > (firstPeak*0.98)*i2){
							
							// make sure harmonic to be added is next sequential harmonic
							if (selectedPeak >= arrayOfHarmonics[arrayOfHarmonics.length-1] + firstPeak*.9) {
								//trace("Adding harmonic 	"+selectedPeak);
								arrayOfHarmonics.push(selectedPeak);
								arrayOfHarmonicsAmplitude.push(selectedPeakAmp);
	
								magOfPeaks.splice(i,1);
								freqOfPeaks.splice(i,1);
								i--;
								noteHasHarmonics = true;
								
								if (i2 <= 3) {
									// third sequential harmonic indicates note played
									
								}
								break;
							}
							else {
								if (i2 == 2) {
									//trace("should break outerloop, 2nd harmonic doesnt exist"); 
									//break outerLoop;
								}
								freqOfPeaks.splice(i,1);
								magOfPeaks.splice(i,1);
								i--;
								break;
							}
						}
					}
				}
				
				if (arrayOfHarmonics.length >= 3) {
					startTime = getTimer() * 0.001;
					
					var timeDiff:Number = new Number(0.21);
					
					// check if previous note is within .45 seconds and ifso and it is the same freq, check if the amplitude is decreased, if so TRASHHHH
					// replace 7 with dynamic value based on minimum distance(freq) between frets, so at higher freq it is > 7
					if (previousNotesPlayedTime[previousNotesPlayedTime.length-1] > startTime - timeDiff && 
						previousNotesPlayedFreq[previousNotesPlayedTime.length-1] > arrayOfHarmonics[0] - 7 &&
						previousNotesPlayedFreq[previousNotesPlayedTime.length-1] < arrayOfHarmonics[0] + 7 ){
						// through out this note cuz its CRAP. CRAP!
						//trace("note -1 is some shiiiiii");
					}
					else if (previousNotesPlayedTime[previousNotesPlayedTime.length-2] > startTime - timeDiff && 
						previousNotesPlayedFreq[previousNotesPlayedTime.length-2] > arrayOfHarmonics[0] - 7 &&
						previousNotesPlayedFreq[previousNotesPlayedTime.length-2] < arrayOfHarmonics[0] + 7 ){
						// through out this note cuz its CRAP. CRAP!
						//trace("note -2 is some shiiiiii");
					}
					else if (previousNotesPlayedTime[previousNotesPlayedTime.length-3] > startTime - timeDiff && 
						previousNotesPlayedFreq[previousNotesPlayedTime.length-3] > arrayOfHarmonics[0] - 7 &&
						previousNotesPlayedFreq[previousNotesPlayedTime.length-3] < arrayOfHarmonics[0] + 7 ){
						// through out this note cuz its CRAP. CRAP!
						//trace("note -3 is some shiiiiii");
					}
					else if (previousNotesPlayedTime[previousNotesPlayedTime.length-4] > startTime - timeDiff && 
						previousNotesPlayedFreq[previousNotesPlayedTime.length-4] > arrayOfHarmonics[0] - 7 &&
						previousNotesPlayedFreq[previousNotesPlayedTime.length-4] < arrayOfHarmonics[0] + 7 ){
						// through out this note cuz its CRAP. CRAP!
						//trace("note -3 is some shiiiiii");
					}
					else if (previousNotesPlayedTime[previousNotesPlayedTime.length-5] > startTime - timeDiff && 
						previousNotesPlayedFreq[previousNotesPlayedTime.length-5] > arrayOfHarmonics[0] - 7 &&
						previousNotesPlayedFreq[previousNotesPlayedTime.length-5] < arrayOfHarmonics[0] + 7 ){
						// through out this note cuz its CRAP. CRAP!
						//trace("note -3 is some shiiiiii");
					}
					else if (previousNotesPlayedTime[previousNotesPlayedTime.length-6] > startTime - timeDiff && 
						previousNotesPlayedFreq[previousNotesPlayedTime.length-6] > arrayOfHarmonics[0] - 7 &&
						previousNotesPlayedFreq[previousNotesPlayedTime.length-6] < arrayOfHarmonics[0] + 7 ){
						// through out this note cuz its CRAP. CRAP!
						//trace("note -3 is some shiiiiii");
					}
					// check for harmonic from result of decaying note. remove if so
					else if (previousNotesPlayedTime[previousNotesPlayedTime.length-1] > startTime - timeDiff &&
						previousNotesPlayedFreq[previousNotesPlayedTime.length-1]*2 < ((arrayOfHarmonics[0]) + 7) &&
						previousNotesPlayedFreq[previousNotesPlayedTime.length-1]*2 > ((arrayOfHarmonics[0]) - 7)) {
								// through out this note cuz its CRAP. CRAP!
								//trace("2 harmonic from decay is some shiiiiii");
							
						}
					
					else {
						//trace(startTime+" note played at "+arrayOfHarmonics[0]);					
							
							// send note to find the name ex. 82Hz is an E2
							convertToAlphaNote(arrayOfHarmonics[0]);
							
							previousNotesPlayedFreq.push(arrayOfHarmonics[0]);
							previousNotesPlayedAmpl.push(arrayOfHarmonicsAmplitude[0]);
							previousNotesPlayedTime.push(startTime);
							
							for (var iVar:Number = 0; iVar<arrayOfHarmonics.length; iVar++) {
								trace(" note freq	"+arrayOfHarmonics[iVar]+"	note ampl	"+arrayOfHarmonicsAmplitude[iVar]);
		
							}
					}
					

					
				}
				
				
				
				if(noteHasHarmonics = true) {
					arrayOfFF.push(firstPeak);				// add note before while loop reruns
					arrayOfFFAmpl.push(firstPeakAmpl);		// add note before while loop reruns
				} 	
			
				// if array has more than 3 harmonics, investigate for further notes
				if (arrayOfHarmonics.length > 3) {
				
					// CHECK AMPLITUDE OF HARMONICS TO SEE IF ANOTHER OCTAVE WAS PLAYED
					
					/**
					 * A AMPLITUDE CLOSER THAN 50% OF A NON FF PAIR, INDICATES ANOTHER OCTAVE
					 * may consider building in presets For Example:
					 * open low E string has strong 1st and 3rd harmonic relative to other strings
					 **/
					
					/*// echo array of harmonics
					for (var i:int = 0; i<arrayOfHarmonics.length; i++){
						trace("Harmonic "+i+ " is " +arrayOfHarmonics[i] + " with ampl " +arrayOfHarmonicsAmplitude[i]);
					}*/
					var firstOctaveRatio:Number  = new Number(.75);
					var fifthOctaveRatio:Number	 = new Number(.55);
					var secondOctaveRatio:Number = new Number(.25);
					
					var additionConstant:Number = (arrayOfHarmonicsAmplitude[0]);
					
					if(arrayOfHarmonicsAmplitude[3] > arrayOfHarmonicsAmplitude[1]*(firstOctaveRatio+additionConstant)){
						//trace("Octave played at " +arrayOfHarmonics[1]);
						arrayOfFF.push(arrayOfHarmonics[1]);
					}
					if(arrayOfHarmonicsAmplitude[5] > arrayOfHarmonicsAmplitude[2]*(fifthOctaveRatio+additionConstant)){
						//trace("Fifth played at " +arrayOfHarmonics[2]);
						arrayOfFF.push(arrayOfHarmonics[2]);
					}
					if(arrayOfHarmonicsAmplitude[7] > arrayOfHarmonicsAmplitude[3]*(secondOctaveRatio)){
						//trace("Second Octave played at " +arrayOfHarmonics[3]);
						arrayOfFF.push(arrayOfHarmonics[3]);
					}
				}
				// store time, FF, ampl of FF in array
				
				}

		}	
		
		private function convertToAlphaNote(noteFreq:Number):String {
			// time keep
			var startTime:Number = new Number;
			startTime = getTimer() * 0.001;
			
			var noteString:String = new String;
			var noteAlphaNames:Array = new Array; 						// array with all the note names on index i
			var noteAlphaFreqs:Array = new Array;						// array with all the note freqa on index i
			
			noteAlphaNames = ["C#2/Db2", "D2", "D#2/Eb2", "E2",	"F2", "F#2/Gb2", "G2", "G#2/Ab2", "A2", "A#2/Bb2", "B2", "C3", "C#3/Db3", "D3",	
							  "D#3/Eb3", "E3", "F3", "F#3/Gb3", "G3", "G#3/Ab3", "A3", "A#3/Bb3", "B3",	"C4", "C#4/Db4", "D4", "D#4/Eb4", "E4",
							  "F4", "F#4/Gb4", "G4", "G#4/Ab4",	"A4", "A#4/Bb4", "B4", "C5", "C#5/Db5", "D5", "D#5/Eb5", "E5", "F5", "F#5/Gb5", 
							  "G5", "G#5/Ab5", "A5", "A#5/Bb5", "B5", "C6", "C#6/Db6", "D6", "D#6/Eb6",	"E6", "F6",	"F#6/Gb6", "G6", "G#6/Ab6"];
			
			noteAlphaFreqs = [69.3,	73.42, 77.78, 82.41, 87.31, 92.5, 98, 103.83, 110, 116.54, 123.47, 130.81, 138.59, 146.83, 155.56, 164.81, 
							  174.61, 185, 196, 207.65, 220, 233.08, 246.94, 261.63, 277.18, 293.66, 311.13, 329.63, 349.23, 369.99, 392, 415.3,
							  440, 466.16, 493.88, 523.25, 554.37, 587.33, 622.25, 659.26, 698.46, 739.99, 783.99, 830.61, 880, 932.33, 987.77,
							  1046.5, 1108.73, 1174.66, 1244.51, 1318.51, 1396.91, 1479.98, 1567.98, 1661.22]
				
			//trace("noteAlphaName.length = && noteAlphaFreqs = "+noteAlphaNames.length +" "+noteAlphaFreqs.length);
			
			for (var i:Number = 1; i < noteAlphaFreqs.length; i++) {
				
				var centerNote:Number = noteAlphaFreqs[i]
				var leftNoteDifference:Number  = noteAlphaFreqs[i-1] - centerNote;		// negative diff between middle and left of middle note
				var rightNoteDifference:Number = noteAlphaFreqs[i+1] - centerNote;
					
				var freqFitDifference:Number = noteFreq - centerNote;				
				
				// finds the closest fit for the freq in the array of freqs
				if ( leftNoteDifference/2 < freqFitDifference && freqFitDifference < rightNoteDifference/2) {
					trace(startTime.toFixed(3) + " Note is "+noteAlphaNames[i]+" becuase sent value of "+noteFreq+ " is close to "+noteAlphaFreqs[i]);
				}
			}
			
			return noteString;
		}
		/**
		 * Draw a graph of the spectrum
		 */
		
		private function findChordAlgo(arrayOfNotes:Array):void {
			var chord2NoteCombinationsArray:Array = new Array;
			var chord3NoteCombinationsArray:Array = new Array;
			var chord4NoteCombinationsArray:Array = new Array;
			var chord5NoteCombinationsArray:Array = new Array;
			
			switch(arrayOfNotes.length) {
				case 0:
					trace("array of notes 0 - findChordAlgo");
					break;
				case 1:
					for ( var i2:Number = 0; i2 < chord2NoteCombinationsArray.length; i2++) {
						
					}
					break;
				case 2:
					for ( var i2:Number = 0; i2 < chord2NoteCombinationsArray.length; i2++) {
						
					}
					break;
				case 3:
					for ( var i2:Number = 0; i2 < chord3NoteCombinationsArray.length; i2++) {
						
					}
					break;
				case 4:
					for ( var i2:Number = 0; i2 < chord4NoteCombinationsArray.length; i2++) {
						
					}
					break;
				case 1:
					for ( var i2:Number = 0; i2 < chord2NoteCombinationsArray.length; i2++) {
						
					}
					break;
				default:
					break;
			}
			
		}

		private function drawSpectrum( 
			mag:Vector.<Number>,
			freq:Vector.<Number> ):void
		{
			// Basic constants
			const MIN_FREQ:Number = 0;					// Minimum frequency (Hz) on horizontal axis.
			const MAX_FREQ:Number = 1500;				// Maximum frequency (Hz) on horizontal axis.
			const FREQ_STEP:Number = 100;				// Interval between ticks (Hz) on horizontal axis.
			const MAX_DB:Number = -0.0;					// Maximum dB magnitude on vertical axis.
			const MIN_DB:Number = -60.0;				// Minimum dB magnitude on vertical axis.
			const DB_STEP:Number = 10;					// Interval between ticks (dB) on vertical axis.
			const TOP:Number  = 50;						// Top of graph
			const LEFT:Number = 60;						// Left edge of graph
			const HEIGHT:Number = 600;					// Height of graph
			const WIDTH:Number = 900;					// Width of graph
			const TICK_LEN:Number = 10;					// Length of tick in pixels
			const LABEL_X:String = "Frequency (Hz)";	// Label for X axis
			const LABEL_Y:String = "dB";				// Label for Y axis
			
			// Derived constants
			const BOTTOM:Number = TOP+HEIGHT;					// Bottom of graph
			const DBTOPIXEL:Number = HEIGHT/(MAX_DB-MIN_DB);	// Pixels/tick
			const FREQTOPIXEL:Number = WIDTH/(MAX_FREQ-MIN_FREQ);// Pixels/Hz 
			
			//-----------------------			
			
			var i:uint;
			var numPoints:uint;
			
			numPoints = mag.length;
			if ( mag.length != freq.length )
				trace( "mag.length != freq.length" );
			
			graphics.clear();
			
			// Draw a rectangular box marking the boundaries of the graph
			graphics.lineStyle( 1, objectColor );
			graphics.drawRect( LEFT, TOP, WIDTH, HEIGHT );
			graphics.moveTo(LEFT, TOP+HEIGHT);
			
			//--------------------------------------------
			
			// Tick marks on the vertical axis			
			var y:Number;
			var x:Number;
			for ( var dBTick:Number = MIN_DB; dBTick <= MAX_DB; dBTick += DB_STEP )
			{
				y = BOTTOM - DBTOPIXEL*(dBTick-MIN_DB);
				graphics.moveTo( LEFT-TICK_LEN/2, y );
				graphics.lineTo( LEFT+TICK_LEN/2, y );
				if ( m_tickTextAdded == false )
				{
					// Numbers on the tick marks
					var t:TextField = new TextField();
					t.text = int(dBTick).toString();
					t.width = 0;
					t.height = 20;
					t.x = LEFT-20;
					t.y = y - t.textHeight/2;
					t.autoSize = TextFieldAutoSize.CENTER;
					// Color of Text
					var tfFormatter:TextFormat = new TextFormat();
					tfFormatter.color = objectColor;
					t.setTextFormat(tfFormatter);
					
					addChild(t);
				}
			} 
			
			// Label for vertical axis
			if ( m_tickTextAdded == false )
			{
				t = new TextField();
				t.text = LABEL_Y;
				t.x = LEFT-50;
				t.y = TOP + HEIGHT/2 - t.textHeight/2;
				t.height = 20;
				t.width = 50;
				//t.rotation = -90;
				
				// Color of Text
				var tfFormatter:TextFormat = new TextFormat();
				tfFormatter.color = objectColor;
				t.setTextFormat(tfFormatter);
				
				addChild(t);
			}
			
			//--------------------------------------------
			
			// Tick marks on the horizontal axis
			for ( var f:Number = MIN_FREQ; f <= MAX_FREQ; f += FREQ_STEP )
			{
				x = LEFT + FREQTOPIXEL*(f-MIN_FREQ);
				graphics.moveTo( x, BOTTOM - TICK_LEN/2 );
				graphics.lineTo( x, BOTTOM + TICK_LEN/2 );
				if ( m_tickTextAdded == false )
				{
					t = new TextField();
					t.text = int(f).toString();
					t.width = 0;
					t.x = x;
					t.y = BOTTOM+7;
					t.autoSize = TextFieldAutoSize.CENTER;
					// Color of Text
					var tfFormatter:TextFormat = new TextFormat();
					tfFormatter.color = objectColor;
					t.setTextFormat(tfFormatter);
					
					addChild(t);
				}
			}
			
			// Label for horizontal axis 
			if ( m_tickTextAdded == false )
			{
				t = new TextField();
				t.text = LABEL_X;
				t.width = 0;
				t.x = LEFT+WIDTH/2;
				t.y = BOTTOM+30;
				t.autoSize = TextFieldAutoSize.CENTER;
				
				// Color of Text
				var tfFormatter:TextFormat = new TextFormat();
				tfFormatter.color = objectColor;
				t.setTextFormat(tfFormatter);
				
				addChild(t);
			}
			
			m_tickTextAdded = true;
			
			
			// -------------------------------------------------			
			// The line in the graph
			
			// Ignore points that are too far to the left
			for ( i = 0; i < numPoints && freq[i] < MIN_FREQ; i++ )
			{
			}

			// For all remaining points within range of x-axis			
			var firstPoint:Boolean = true;
			for ( /**/; i < numPoints && freq[i] <= MAX_FREQ; i++ )
			{
				// Compute horizontal position
				x = LEFT + FREQTOPIXEL*(freq[i]-MIN_FREQ);
				
				
				// convert to dB scale
				// 20 log10(mag) => 20/ln(10) ln(mag)
				const SCALE:Number = 20/Math.LN10;		
				mag[i] = SCALE*Math.log(mag[i] + Number.MIN_VALUE );

				// Compute vertical position of point
				// and clip at top/bottom.
				y = BOTTOM - DBTOPIXEL*(mag[i]-MIN_DB);
				if ( y < TOP )
					y = TOP;
				else if ( y > BOTTOM )
					y = BOTTOM;
				
				// If it's the first point				
				if ( firstPoint )
				{
					// Move to the point
					graphics.moveTo(x,y);
					firstPoint = false;
				}
				else
				{
					// Otherwise, draw line from the previous point
					graphics.lineTo(x,y);
				}
			}
		}			
	}
}