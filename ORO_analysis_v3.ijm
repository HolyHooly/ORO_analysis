//==========================================================
// C. elegans Oil Red O image Quantification ImageJ macro
// version 3. - User Friendly version
// May. 18. 2023.
// DGIST (DaeguGyeongbuk Institute of Science & Technology)
// Taehyun Kim
//==========================================================

//=============== User Settings ============================
//Caution: global variables

save_file_name = "Measurements"; //file name for measurements
move_done_images = false; //true: move image from input directory to output directory after processing
color_space = "Lab"; //threshold color space (ex) Lab, YUV, RGB, HSB

wormedge_from_saved_rois = true;
prefix = "";
suffix = "-WBcorrected.jpg";

//for threshold setting, please make sure it works before batch process
threshold_value = newArray(0,100,128,255,0,255); //channel1 min, max; channel2 min, max; channel3 min, max
threshold_type = newArray("pass", "pass", "pass"); //threshold type: "pass" or "stop"

worm_detection_cspace = "Lab";
worm_detection_threshold = newArray(0,193,0,255,0,255); //threshold for worm detection
worm_detection_type = newArray("pass", "pass", "pass"); //threshold type: "pass" or "stop"

//=============== User Setting End =========================
//==========================================================
//=============== Main =====================================

if(wormedge_from_saved_rois == true){
	_input_dir = getDirectory("Choose input directory");
	_output_dir = getDirectory("Choose output directory");
	_roi_input_dir = getDirectory("Choose ROI input directory");
	
	img_list = getFileList(_input_dir);
	
	for(i=0;i<img_list.length; i++){ //image batch
		open(_input_dir+img_list[i]);
		a = substring(img_list[i], 0, lengthOf(img_list[i])-lengthOf(suffix));
		roi_path = _roi_input_dir + a + File.separator;
		roi_list = getFileList(roi_path);
		
		worm_num = (roi_list.length-2)/4;
	
		for(j=0;j<roi_list.length;j++){
			b = substring(roi_list[j], 0, lengthOf(roi_list[j])-5);
			if(b=="worm_edge_"){
				roiManager("open", roi_path + roi_list[j]);
			}
		}
		
		ORO_analysis_saved_roi(worm_num);
		
		
	}
	
	
}

else{
	input_dir = getDirectory("Choose input directory");
	output_dir = getDirectory("Choose output directory");
	roi_output_dir = getDirectory("Choose ROI output directory");
	
	//batch starts
	img_list = getFileList(input_dir); //fetch image list from input directory
	for(i=0; i<img_list.length; i++){
		showProgress(i+1, img_list.length);
		open(input_dir+img_list[i]);
		
		ORO_analysis_v3(); //main function
		
		print(img_list[i] + "...done");
		saveAs("results", output_dir + save_file_name + ".csv"); //save measurements periodically
		
		if(move_done_images){
			File.copy(input_dir+img_list[i], output_dir + File.separator + img_list[i]);
			File.delete(input_dir+img_list[i]);
		}
	}//batch ends
}







//=============== Main End =================================
//=============== Function Declarations ====================
function ORO_analysis_v3(){
	img_title=getTitle();
	run("Duplicate...", "title=Mask");
	
	
	//worm number input from user
	Dialog.create("Worm Number");
	Dialog.addNumber("How many worms?", 1);
	Dialog.show();
	worm_num = Dialog.getNumber();

	
	//ORO color threshold
	ORO_detection_color_threshold(threshold_value, threshold_type, color_space);
	//roiManager("Add"); //whole image color threshold selection at #
	roiManager("select", 0);
	roiManager("rename", "Whole_ORO");
	close("Mask");
	
	//Worm Detection
	run("Duplicate...", "title=Mask");
	ORO_detection_color_threshold(worm_detection_threshold, worm_detection_type, worm_detection_cspace);
	//roiManager("Add"); //whole worm detection ROI at #1
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

function ORO_analysis_saved_roi(worm_num){
	img_title=getTitle();
	run("Duplicate...", "title=Mask");
	ORO_detection_color_threshold(threshold_value, threshold_type, color_space);
	roiManager("select", worm_num);
	roiManager("rename", "Whole_ORO");
	close("Mask");
	
	for(i=0;i<worm_num;i++){
		roiManager("select", newArray(i, worm_num));
		roiManager("and");
		roiManager("Add");
		n = roiManager("count")-1;
		roiManager("select", n);
		roiManager("rename", "worm_ORO_"+i);
	}
	
	for(i=1;i<=worm_num;i++){
		roiManager("select", worm_num+i); //ORO select
		run("Set Measurements...", "area mean standard min perimeter shape integrated WormArea WormAreaMean WormAreaMin WormAreaMax Length display redirect=None decimal=3");
		roiManager("measure"); //ORO measure
		area = getResult("Area", nResults-1);
		mean = getResult("Mean", nResults-1);
		min = getResult("Min", nResults-1);
		max = getResult("Max", nResults-1);
		print(area, mean, min, max);
		
		roiManager("select", i-1); //whole worm select
		run("Set Measurements...", "area mean standard min perimeter shape integrated WormArea WormAreaMean WormAreaMin WormAreaMax Length display redirect=None decimal=3");
		roiManager("measure"); //whole worm measure
		worm_area = getResult("Area", nResults-1);
		worm_mean = getResult("Mean", nResults-1);
		worm_min = getResult("Min", nResults-1);
		worm_max = getResult("Max", nResults-1);
		print(worm_area, worm_mean, worm_min, worm_max);
		
		setResult("WormArea", nResults-2, worm_area);
		setResult("WormAreaMean", nResults-2, worm_mean);
		setResult("WormAreaMin", nResults-2, worm_min);
		setResult("WormAreaMax", nResults-2, worm_max);
		
		IJ.deleteRows(nResults-1, nResults-1);
		
	}
	close(img_title);
	roiManager("reset");
	worm_num=1;
	
	
	
}

function ORO_detection_color_threshold(_range, _type, _cspace){
	
	_original_title=getTitle();
	
	if(_cspace=="Lab"){
		call("ij.plugin.frame.ColorThresholder.RGBtoLab");
		run("RGB Stack");
		_name = newArray("Red", "Green", "Blue");
	}
	else if(_cspace=="YUV"){
		call("ij.plugin.frame.ColorThresholder.RGBtoYUV");
		run("RGB Stack");
		_name = newArray("Red", "Green", "Blue");
	}
	else if(_cspace=="HSB"){
		run("HSB Stack");
		_name = newArray("Hue", "Saturation", "Brightness");
	}
	else if(_cspace=="RGB"){
		run("RGB Stack");
		_name = newArray("Red", "Green", "Blue");
	}
	
	run("Convert Stack to Images");
	
	for (i=0;i<3;i++){
		selectWindow(_name[i]); rename(""+i);
	}
	
	for (i=0;i<3;i++){
	  selectWindow(""+i);
	  setThreshold(_range[i*2], _range[i*2+1]);
	  //print(_range[i*2], _range[i*2+1]);
	  run("Convert to Mask");
	  if (_type[i]=="stop")  run("Invert");
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
	rename(_original_title);
	
	setThreshold(1,255);
	run("Create Selection"); //ROI selection for whole image
	roiManager("Add");
}

function measure_worm(num){

	roiManager("Select",newArray(0,1)); //select whole image ROI from color threshold
	roiManager("show all");


	drawn_worm_index = _draw_a_worm_to_ROIManager();
	roiManager("Select", drawn_worm_index);
	roiManager("rename", "worm_"+num);
	
	roiManager("Select", newArray(0,drawn_worm_index));
	roiManager("and");
	roiManager("Add");
	a_worm_ORO_index =roiManager("count"); a_worm_ORO_index--;
	roiManager("Select",a_worm_ORO_index);
	roiManager("rename", "worm_ORO_"+num);
	run("Set Measurements...", "area mean standard min perimeter shape integrated WormArea WormAreaMean WormAreaMin WormAreaMax Length display redirect=None decimal=3");
	roiManager("measure"); //worm ORO measure
	area = getResult("Area", nResults-1);
	mean = getResult("Mean", nResults-1);
	min = getResult("Min", nResults-1);
	max = getResult("Max", nResults-1);
	print(area, mean, min, max);
	
	roiManager("Select",newArray(1,drawn_worm_index)); //1-worm edge, 2-user one worm
	roiManager("and");
	roiManager("Add");
	a_worm_area_index =roiManager("count"); a_worm_area_index--;
	roiManager("Select",a_worm_area_index);
	roiManager("rename", "worm_edge_"+num);
	run("Set Measurements...", "area mean standard min perimeter shape integrated WormArea WormAreaMean WormAreaMin WormAreaMax Length display redirect=None decimal=3");
	roiManager("measure");
	
	worm_area = getResult("Area", nResults-1);
	worm_mean = getResult("Mean", nResults-1);
	worm_min = getResult("Min", nResults-1);
	worm_max = getResult("Max", nResults-1);
	print(worm_area, worm_mean, worm_min, worm_max);


	worm_length_index = _draw_a_worm_length_andto_ROIManager();//for worm length measurement
	roiManager("Select",worm_length_index); //length ROI
	roiManager("rename", "worm_midline_"+num);
	run("Set Measurements...", "area mean standard min perimeter shape integrated WormArea WormAreaMean WormAreaMin WormAreaMax Length display redirect=None decimal=3");
	roiManager("measure");
	length = getResult("Length", nResults-1);

	setResult("WormArea", nResults-3, worm_area);
	setResult("WormAreaMean", nResults-3, worm_mean);
	setResult("WormAreaMin", nResults-3, worm_min);
	setResult("WormAreaMax", nResults-3, worm_max);
	setResult("Length", nResults-3, length);
	
	
	IJ.deleteRows(nResults-2, nResults-1);
	
	_save_ROI(roi_output_dir);
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
function _save_ROI(output_dir){
	img_title=getTitle();
	output_dir_image = output_dir + File.separator + img_title;

	cnt = roiManager("count");
	File.makeDirectory(output_dir_image);

	for(i=0;i<cnt;i++){
		roiManager("select", i);
		name = Roi.getName();
		roiManager("save selected", output_dir_image + File.separator + name + ".roi");
	}
}



//=============== Function Declarations End ================