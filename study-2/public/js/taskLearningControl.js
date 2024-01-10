// import task info from versionInfo file
import { nBlocksLearning, debugging, allowDevices } from "./versionInfo.js"; 
import { trialsC } from "./trialsControl.js"; 
 
// import our data saving function
import { saveTaskData, saveQuestData } from "./saveData.js";

// import jspsych object so can access modules
import { jsPsych } from "./constructStudy.js";

// initialize task vars
var nTrialsLearning;
var timeBeforeChoice = 750;         // time in ms before choice can be entered
var trialTimeoutTime;               // time in ms after which trial times out
var feedbackTime = 2500;            // time in ms feedback is displayed on screen
var nTimeouts = 0;
var blockNo = 0;
var trialEvents;
var trialValence;
var trialAttrIntGlob;
var trialAttrIntSpec;
var trialAttrExtGlob;
var trialAttrExtSpec;
var scenarioColours = ["#D5D6EA", "#D7ECD9", "#F6F6EB"];

// grab trial info
//trialEvents = trials.events;
trialValence = trialsC.event_valence;
trialAttrIntGlob = trialsC.int_glob;
trialAttrIntSpec = trialsC.int_spec;
trialAttrExtGlob = trialsC.ext_glob;
trialAttrExtSpec = trialsC.ext_spec

// set number of trials, blocklength, and max trial length according to debug condition
if ( debugging == false ) {
    nTrialsLearning = trialValence.length;
    trialTimeoutTime = 15000;
} else {
    nTrialsLearning = 12;
    trialTimeoutTime = 4000;
}
var blockLengthLearning = Math.round(nTrialsLearning/nBlocksLearning); 

///////////////////////////////////////////// LEARNING TASK TIMELINE /////////////////////////////////////////////////////////
var timeline_learning_control = [];

// define trial stimuli and choice array for use as a timeline variable 
var events_causes_learning = [];
for ( var i = 0; i < nTrialsLearning; i++ ) {
    var itemNo = i; 
    events_causes_learning[i] = { 
                               trialIndex: i,
                               stimulus: null,
                               valence: trialValence[itemNo],
                               intGlob: trialAttrIntGlob[itemNo],
                               intSpec: trialAttrIntSpec[itemNo],
                               extGlob: trialAttrExtGlob[itemNo],
                               extSpec: trialAttrExtSpec[itemNo],
                               itemNo: itemNo,
                               blockNo: null,
                               choice1: null,
                               choice2: null,
                               correct_answer: null };
    if ( i <= blockLengthLearning-1 ) {
        events_causes_learning[i].choice1 = trialAttrIntGlob[itemNo];
        events_causes_learning[i].choice2 = trialAttrIntSpec[itemNo];
        if ( trialValence[itemNo] == "negative") {
            events_causes_learning[i].stimulus = "blue-basket.png";
            events_causes_learning[i].correct_answer = trialAttrIntSpec[itemNo];
        } else {
            events_causes_learning[i].stimulus = "red-basket.png";
            events_causes_learning[i].correct_answer = trialAttrIntGlob[itemNo];
        }
        events_causes_learning[i].blockNo = 1;
    } else if ( i <= blockLengthLearning*2-1 ) {
        events_causes_learning[i].choice1 = trialAttrIntGlob[itemNo];
        events_causes_learning[i].choice2 = trialAttrExtGlob[itemNo];
        if ( trialValence[itemNo] == "negative") {
            events_causes_learning[i].stimulus = "blue-basket.png";
            events_causes_learning[i].correct_answer = trialAttrExtGlob[itemNo];
        } else {
            events_causes_learning[i].stimulus = "red-basket.png";
            events_causes_learning[i].correct_answer = trialAttrIntGlob[itemNo];
        }
        events_causes_learning[i].blockNo = 2;
    } else if ( i <= blockLengthLearning*3-1 ) {
        events_causes_learning[i].choice1 = trialAttrIntGlob[itemNo];
        events_causes_learning[i].choice2 = trialAttrExtSpec[itemNo];
        if ( trialValence[itemNo] == "negative") {
            events_causes_learning[i].stimulus = "blue-basket.png";
            events_causes_learning[i].correct_answer = trialAttrExtSpec[itemNo];
        } else {
            events_causes_learning[i].stimulus = "red-basket.png";
            events_causes_learning[i].correct_answer = trialAttrIntGlob[itemNo];
        }
        events_causes_learning[i].blockNo = 3;
    }
};

// define individual choice trials
var learningTrialNo = 0;
var learning_choice_types = ['choice1', 'choice2'];
var learning_trial = {
    // jsPsych plugin to use
    type: jsPsychHtmlButtonResponseCA,
    // trial info
    prompt: null,  
    stimulus: function () {
        var stim = "<div class='center-content'><img src='../assets/imgs/tlc/"+jsPsych.timelineVariable('stimulus')+"' style='width:200px;'></img></div>"+
                   "<div class='center-content'><img src='../assets/imgs/head_why.png' style='width:200px;'></img></div>";  // placeholder for fb img
        return stim;
    },
    choices: function () {
        var display_order = jsPsych.randomization.repeat(learning_choice_types, 1);
        var choices_ordered = [ jsPsych.timelineVariable(display_order[0]), 
                                jsPsych.timelineVariable(display_order[1]) ];
        return choices_ordered;
    },
    save_trial_parameters: {
        choices: true
    },
    // trial timing
    trial_duration: trialTimeoutTime,       // after this time, move on to next trial (but trial re-added)
    stimulus_duration: null,                // stim text remains on screen indefinitely
    time_before_choice: timeBeforeChoice,   // time in ms before the ppt can enter a choice
    response_ends_trial: true,              // trial ends only when response entered
    time_after_choice: 750,                 // time in ms to leave trial info on screen following choice
    post_trial_gap: 0,                     
    // styling
    margin_vertical: '0px',                 // vertical margin of the button (px)
    margin_horizontal: '20px',              // horizontal margin of the button (px)
    button_html: function() {
        var cloud_button =  "<div class='thought'><img src='../assets/imgs/tlc/%choice%' style='width:180px;'></img></div>";  // use images as repsonse buttons
        return cloud_button;
    },
    // at end of each trial
    on_finish: function(data, trial) {
        // add chosen interpretation type to output
        data.stimulus = jsPsych.timelineVariable('stimulus');
        data.valence = jsPsych.timelineVariable('valence');
        data.itemNo = jsPsych.timelineVariable('itemNo'); 
        data.trialNo = learningTrialNo;
        data.blockNo = jsPsych.timelineVariable('blockNo'); 
        // did participant enter a choice for the trial?
        if (data.response == null) {
            // if the participant didn't respond...
            data.timedout = true;
            data.correct = null;
            data.chosen_attr_type = null;
            nTimeouts++;
        } else {
            // if the participant responded...
            data.timedout = false;
            // was chosen attribution the 'correct' option?
            data.chosen_attr = data.choices[data.response];
            if ( data.chosen_attr == jsPsych.timelineVariable('correct_answer')) {
                data.correct = 1;
            } else {
                data.correct = 0;
            };
            // what attribution type was chosen?
            data.chosen_attr_type = '';
            if ( data.chosen_attr == jsPsych.timelineVariable('intGlob') ) {
                data.chosen_attr_type = "internal_global";
            } else if ( data.chosen_attr  == jsPsych.timelineVariable('intSpec') ) {
                data.chosen_attr_type = "internal_specific";
            } else if ( data.chosen_attr == jsPsych.timelineVariable('extGlob') ) {
                data.chosen_attr_type = "external_global";
            } else if ( data.chosen_attr  == jsPsych.timelineVariable('extSpec') ) {
                data.chosen_attr_type = "external_specific";
            }; 
        }
        data.nTimeouts = nTimeouts;
        // save data and increment trial number
        var respData = jsPsych.data.getLastTrialData().trials[0];
        saveTaskData("learningTask_"+learningTrialNo, respData);
        learningTrialNo++;
        // // manually update progress bar so just reflects task progress
        // var curr_progress_bar_value = this.type.jsPsych.getProgressBarCompleted();
        // this.type.jsPsych.setProgressBar(curr_progress_bar_value + 1/nTrials);
    }
};

var feedback = {
    type: jsPsychHtmlButtonResponse,
    is_html: true,
    // display previous choice options
    choices: function () {
        var prev_data = jsPsych.data.getLastTrialData().trials[0];
        return prev_data.choices;
    },
    button_html: function() {
        var cloud_button =  "<div class='thought'><img src='../assets/imgs/tlc/%choice%' style='width:180px;'></img></div>";  // our custom 'thought cloud' css button
        var prev_data = jsPsych.data.getLastTrialData().trials[0];
        if ( prev_data.timedout == false ) {
            return cloud_button;
        } else {
            return "";
        }
    },
    // highlight correct response in green text
    on_load: function () {
        var prev_data = jsPsych.data.getLastTrialData().trials[0];
        if ( prev_data.timedout == false & prev_data.choices[0] == jsPsych.timelineVariable('correct_answer') ) {
            document.getElementById('jspsych-html-button-response-button-0').style.color = 'green';
        } else if ( prev_data.timedout == false ) {
            document.getElementById('jspsych-html-button-response-button-1').style.color = 'green';
        }
    },
    // and give response-contingent feedback
    stimulus: function () {
        var prev_data = jsPsych.data.getLastTrialData().trials[0];
        var stim_fb;
        if ( prev_data.timedout == false & prev_data.correct == 1 ) {
            stim_fb = "<div class='center-content'><img src='../assets/imgs/tlc/"+jsPsych.timelineVariable('stimulus')+"' style='width:200px;'></img></div>"+
                          "<div class='center-content'><img src='../assets/imgs/head_correct.png' style='width:200px;'></img></div>";
        } else if ( prev_data.timedout == false ) {
            stim_fb = "<div class='center-content'><img src='../assets/imgs/tlc/"+jsPsych.timelineVariable('stimulus')+"' style='width:200px;'></img></div>"+
                          "<div class='center-content'><img src='../assets/imgs/head_incorrect.png' style='width:200px;'></img></div>"; 
        } else {
            stim_fb = "<p style='font-size:30px; font-weight: bold; color: red;'><br> You didn't choose in time!<br></p>"
        }
        return stim_fb;
    },
    // feedback displayed for set amount of time for all outcome types
    trial_duration: feedbackTime,           // feedback displayed for this time
    response_ends_trial: false,             // despite any participant repsonses
    stimulus_duration: feedbackTime,        // feedback displayed for this time
    post_trial_gap: 750                     // post trial gap (ITI)              
};

// define intro text screen
var task_intro = {
    type: jsPsychHtmlButtonResponse,
    choices: ['start'],
    is_html: true,
    stimulus: function () {
        var stim_br = ("<p><h2>Welcome to the task</h2></p>"+
                    "<br>"+
                    "<p>"+
                    "<b>You are now ready to start learning about the first scenario</b>."+
                    "</p>"+
                    "<p>"+
                    "Remember, in each scenario <i>different "+
                    "kinds of objects may belong in different baskets.</i>"+
                    "</p>"+
                    "<p>"+
                    "Press the button below when you are ready to start!</b>. "+
                    "</p>"+
                    "<br><br><br>"+
                    "</p>")
        return stim_br;
    },
    on_start: function () {
        document.body.style.background = scenarioColours[blockNo];
        blockNo++;
    }
};

// define free text description screen (at end of block)
var freeTextFeedback = {
    type: jsPsychSurvey,
    pages: [
    [
      {
        type: 'html',
        prompt: `<div class='center-content'><img src='../assets/imgs/tlc/blue-basket.png' style='width:150px;'></img></div>`, 
      },
      {
        type: 'text',
        prompt: `Please describe the kinds of objects that belonged in the BLUE BASKET
                 during the previous scenario. A single phrase or sentence is fine!`, 
        name: 'answer_neg', 
        textbox_rows: 2,
        textbox_columns: 60,
        required: true
      },
      {
        type: 'html',
        prompt: `<div class='center-content'><img src='../assets/imgs/tlc/red-basket.png' style='width:150px;'></img></div>`, 
      },
      {
        type: 'text',
        prompt: `Now, please describe the kind of objects that belonged in the RED BASKET
                during the previous scenario.`, 
        name: 'answer_pos', 
        textbox_rows: 2,
        textbox_columns: 60,
        required: true
      },
    ]
    ],
    button_label_finish: 'submit answer',
    on_finish: function() {
        // get response and RT data
        var respData = jsPsych.data.getLastTrialData().trials[0].response;
        var respRT = jsPsych.data.getLastTrialData().trials[0].rt;
        saveQuestData(["freeText_block"+blockNo], respData, respRT);
    }
};

// define cause rating screen (for at the start then after each block)
var causeRatingNeg = {
    type: jsPsychHtmlMultiSliderResponse,
    stimulus: function () {
        var stim_text;
        if ( blockNo == 0 ) {
            stim_text = `<div style="width:750px;">
            <h2> Before you start! </h2>
            <p>Next, we'd like you to <b>look at the object below</b>.</p>
            <div class='center-content'><img src='../assets/imgs/tlc/test-manmade-small.jpg' style='width:200px;'></img></div>
            <p>How would you describe this object using the below scales?</p>
            <p>Click and drag the sliders below until you are happy with your answer,
            then press the 'enter answer' button to continue. You will have to move all the sliders 
            before your answer can be entered.</p>
            </div>`;  
        } else {
            stim_text = `<div style="width:750px;">
            <p><b> Still thinking about the previous scenario, how would you describe  
            the kind of objects which belonged in the BLUE BASKET on the below scales?</b></p>
            <div class='center-content'><img src='../assets/imgs/tlc/blue-basket.png' style='width:150px;'></img></div>
            <p>Click and drag the sliders below until you are happy with your answer,
            then press the 'enter answer' button to continue. You will have to move all the sliders 
            before your answer can be entered.</p>
            </div>`; 
        }
        return stim_text;
    },
    require_movement: true,
    labels: [ ["human-made", 
               'natural'],
              ['bigger than a shoebox', 
               'smaller than a shoebox']
    ],
    button_label: 'enter answer',
    //min: 1, max: 100, slider_start: 50,  // default values
    slider_width: 500,                     // width in px, if null, sets equal to widest element of display
    on_finish: function() {
    // get response and RT data
        var respData = jsPsych.data.getLastTrialData().trials[0].response;
        var respRT = jsPsych.data.getLastTrialData().trials[0].rt;
        saveQuestData(["ratings_neg_block"+blockNo], respData, respRT);
    }
};
var causeRatingPos = {
    type: jsPsychHtmlMultiSliderResponse,
    stimulus: function () {
        var stim_text;
        if ( blockNo == 0 ) {
            stim_text = `<div style="width:750px;">
            <h2> Before you start! </h2>
            <p>Next, we'd like you to <b>look at the object below</b>.</p>
            <div class='center-content'><img src='../assets/imgs/tlc/test-natural-big.jpg' style='width:200px;'></img></div>
            <p>How would you describe this object using the below scales?</p>
            <p>Click and drag the sliders below until you are happy with your answer,
            then press the 'enter answer' button to continue. You will have to move all the sliders 
            before your answer can be entered.</p>
            </div>`; 
        } else {
            stim_text = `<div style="width:750px;">
            <p><b> Still thinking about the previous scenario, how would you describe  
            the kind of objects which belonged in the RED BASKET on the below scales?</b></p>
            <div class='center-content'><img src='../assets/imgs/tlc/red-basket.png' style='width:150px;'></img></div>
            <p>Click and drag the sliders below until you are happy with your answer,
            then press the 'enter answer' button to continue. You will have to move all the sliders 
            before your answer can be entered.</p>
            </div>`; 
        }
        return stim_text;
    },
    require_movement: true,
    labels: [ ["human-made", 
               'natural'],
              ['bigger than a shoebox', 
               'smaller than a shoebox']
    ],
    button_label: 'enter answer',
    //min: 1, max: 100, slider_start: 50,  // default values
    slider_width: 500,                     // width in px, if null, sets equal to widest element of display
    on_finish: function() {
    // get response and RT data
        var respData = jsPsych.data.getLastTrialData().trials[0].response;
        var respRT = jsPsych.data.getLastTrialData().trials[0].rt;
        saveQuestData(["ratings_pos_block"+blockNo], respData, respRT);
    }
};

// define break screen (between blocks)
var takeABreak = {
    type: jsPsychHtmlButtonResponse,
    choices: ['continue'],
    is_html: true,
    stimulus: function () {
        var stim_br;
        if ( blockNo < nBlocksLearning) {
            stim_br = ("<p><h2>Well done!</h2></p>"+
                        "<br>"+
                        "<p>"+
                        "You are <b>now finished with this scenario</b>!"+
                        "</p>"+
                        "<p>"+
                        "When you are ready, <b>press continue to move " +
                        "on</b>. "+
                        "</p>"+
                        "<p>"+
                        "Remember, the kinds of object that belong in each basket may be different "+
                        "to the kinds of objects that were correct during the previous scenario."+
                        "</p>"+
                        "<br><br><br>"+
                        "</p>")
        } else {
            stim_br = ("<p><h2>Well done!</h2></p>"+
                        "<br>"+
                        "<p>"+
                        "You are <b>now finished with this scenario</b>!"+
                        "</p>"+
                        "<p>"+
                        "When you are ready, <b>press continue to move " +
                        "on</b>. "+
                        "</p>"+
                        "<br><br><br>"+
                        "</p>")
        }
        return stim_br;
    },
    on_finish: function () {
        // change background colour to indicate new scenario and increment blockNo
        document.body.style.background = scenarioColours[blockNo];
        blockNo++;
    }
};

// if trial timed out, loop trial and feedback again until participant responds
var learning_trial_node = {
    timeline: [ learning_trial, feedback ],
    loop_function: function () {
        var prev_trial_to = jsPsych.data.getLastTimelineData().trials[0].timedout;
        if ( prev_trial_to == true ) {
            return true; 
        } else {
            return false; 
        }
    }
};

// display these screens if at the end of a block
var learning_break_node = {
    timeline: [ freeTextFeedback, causeRatingNeg, causeRatingPos, takeABreak ],
    conditional_function: function () {
        var trialIndex = jsPsych.timelineVariable('trialIndex')                // use trialIndex not absolute trialNo
        if ( (trialIndex+1) % blockLengthLearning == 0  && trialIndex !=nTrialsLearning ) {
            return true;
        } else {
            return false;
        }
    }
};

// finally, define the whole set of choice trials based on above logic and timeline variables
var learning_trials = {
    timeline: [ learning_trial_node, learning_break_node ],
    timeline_variables: events_causes_learning         
};

///////////////////////////////////////////// CONCAT ////////////////////////////////////////////////////////
timeline_learning_control.push(causeRatingNeg);
timeline_learning_control.push(causeRatingPos);
timeline_learning_control.push(task_intro);
timeline_learning_control.push(learning_trials);        
 
export { timeline_learning_control };
