input_dir = getDirectory("Choose input directory");
output_dir = getDirectory("Choose output directory");
img_list = getFileList(input_dir);
save_file_name = "Measurements";

for(i=0; i<img_list.length; i++){
	showProgress(i+1, img_list.length);
	open(input_dir+img_list[i]);
	
	ORO_analysis_v2();
	print(img_list[i] + "...done");
	saveAs("results", output_dir + save_file_name + ".csv");
	
	sep = File.separator;
	File.copy(input_dir+img_list[i], output_dir + sep + img_list[i]);
	File.delete(input_dir+img_list[i]);

}

//-----------------function declarations-------------
function ORO_analysis_v2(){
	img_title=getTitle();
	run("Duplicate...", "title=Mask");
	
	//worm number input from user
	Dialog.create("Worm Number");
	Dialog.addNumber("How many worms?", 1);
	Dialog.show();
	worm_num = Dialog.getNumber();

	ORO_detection_color_threshold_LAB();
	roiManager("Add"); //whole image color threshold selection at #
	roiManager("select", 0);
	roiManager("rename", "Whole_ORO");
	close("Mask");
	
	run("Duplicate...", "title=Mask");
	worm_area_detection();
	roiManager("Add"); //whole worm detection ROI at #1
	roiManager("select", 1);
	roiManager("rename", "Whole_worm");
	close("Mask");
	

	for(j=0;j<worm_num;j++){
		measure_worm(j);
	}

	close(img_title);
	roiManager("reset");
	worm_num=1;

}

function ORO_detection_color_threshold_LAB(){	
// Color Thresholder 1.53t
	min=newArray(3);
	max=newArray(3);
	filter=newArray(3);
	original_title=getTitle(); //Mask
	call("ij.plugin.frame.ColorThresholder.RGBtoLab");
	run("RGB Stack");
	run("Convert Stack to Images");
	selectWindow("Red");
	rename("0");
	selectWindow("Green");
	rename("1");
	selectWindow("Blue");
	rename("2");
	min[0]=0;
	max[0]=100;
	filter[0]="pass";
	min[1]=128;
	max[1]=255;
	filter[1]="pass";
	min[2]=0;
	max[2]=255;
	filter[2]="pass";
	for (i=0;i<3;i++){
	  selectWindow(""+i);
	  setThreshold(min[i], max[i]);
	  run("Convert to Mask");
	  if (filter[i]=="stop")  run("Invert");
	}

	imageCalculator("AND create", "0","1");
	imageCalculator("AND create", "Result of 0","2");
	
	for (i=0;i<3;i++){
	  selectWindow(""+i);
	  close();
	}
	selectWindow("Result of 0");
	close();
	selectWindow("Result of Result of 0");
	rename(original_title);
	
	// Colour Thresholding-------------
	setThreshold(1,255);
	run("Create Selection"); //ROI selection for whole image
}

function worm_area_detection(){
	min=newArray(3);
	max=newArray(3);
	filter=newArray(3);
	original_title=getTitle();
	call("ij.plugin.frame.ColorThresholder.RGBtoLab");
	run("RGB Stack");
	run("Convert Stack to Images");
	selectWindow("Red");
	rename("0");
	selectWindow("Green");
	rename("1");
	selectWindow("Blue");
	rename("2");
	min[0]=0;
	max[0]=165;
	filter[0]="pass";
	min[1]=0;
	max[1]=255;
	filter[1]="pass";
	min[2]=0;
	max[2]=255;
	filter[2]="pass";
	for (i=0;i<3;i++){
	  selectWindow(""+i);
	  setThreshold(min[i], max[i]);
	  run("Convert to Mask");
	  if (filter[i]=="stop")  run("Invert");
	}

	imageCalculator("AND create", "0","1");
	imageCalculator("AND create", "Result of 0","2");
	
	for (i=0;i<3;i++){
	  selectWindow(""+i);
	  close();
	}
	selectWindow("Result of 0");
	close();
	selectWindow("Result of Result of 0");
	rename(original_title);
	
	// Colour Thresholding-------------
	setThreshold(1,255);
	run("Create Selection");
	
}



function measure_worm(num){

	roiManager("Select",newArray(0,1)); //select whole image ROI from color threshold


	drawn_worm_index = _draw_a_worm_to_ROIManager();
	roiManager("Select", newArray(0,drawn_worm_index));
	roiManager("and");
	roiManager("Add");
	a_worm_ORO_index =roiManager("count"); a_worm_ORO_index--;
	roiManager("Select",a_worm_ORO_index);
	roiManager("rename", "worm_ORO"+num);
	run("Set Measurements...", "area mean standard min perimeter shape integrated display redirect=None decimal=3");
	roiManager("measure");
	
	roiManager("Select",newArray(1,drawn_worm_index)); //1-worm edge, 2-user one worm
	roiManager("and");
	roiManager("Add");
	a_worm_area_index =roiManager("count"); a_worm_area_index--;
	roiManager("Select",a_worm_area_index);
	roiManager("rename", "worm_edge");
	roiManager("measure");
	
	worm_area = getResult("Area", nResults-1);
	worm_mean = getResult("Mean", nResults-1);
	worm_min = getResult("Min", nResults-1);
	worm_max = getResult("Max", nResults-1);
	setResult("WormArea", nResults-2, worm_area);
	setResult("WormAreaMean", nResults-2, worm_mean);
	setResult("WormAreaMin", nResults-2, worm_min);
	setResult("WormAreaMax", nResults-2, worm_max);
	IJ.deleteRows(nResults-1, nResults-1);
	
	
	worm_length_index = _draw_a_worm_length_andto_ROIManager();//for worm length measurement
	roiManager("Select",worm_length_index); //length ROI
	roiManager("rename", "worm_midline");
	roiManager("measure");
	length = getResult("Length", nResults-1);
	setResult("Length", nResults-2, length);
	IJ.deleteRows(nResults-1, nResults-1);
	
	_reset_a_worm();

}

function _draw_a_worm_to_ROIManager(){
	//one worm selection and add to ROIManager
	//and returns index of added ROI
	setTool('freehand');
	waitForUser("Draw ROI of a worm, then hit OK. With no ROI selection, this message keep appears.");
	while(selectionType()<0){
		waitForUser("Draw ROI of a worm, then hit OK. With no ROI selection, this message keep appears.");
	}
	roiManager("Add");
	n=roiManager("count");
	return n-1;
}

function _draw_a_worm_length_andto_ROIManager(){
	setTool('polyline');
	waitForUser("Draw a line of a worm for length, then hit OK.");
	while(selectionType()<0){l
	waitForUser("Draw ROI, then hit OK. Withl no ROI selection, this message keep appears.");
	}
	roiManager("Add");
	n=roiManager("count");
	return n-1;
}

function _reset_a_worm(){
	count = roiManager("count");

	temp = newArray(count-2);
  	for (i=2; i<count; i++) {
		temp[i-2] = i;
	}

	roiManager("Select", temp);
	roiManager("delete");
	
}

function _findRoiWithName(roiName) { 
	nR = roiManager("Count"); 
 
	for (i=0; i<nR; i++) { 
		roiManager("Select", i); 
		rName = Roi.getName(); 
		if (matches(rName, roiName)) { 
			return i; 
		} 
	} 
	return -1; 
} 
