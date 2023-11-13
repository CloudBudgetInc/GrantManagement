import {ShowToastEvent} from "lightning/platformShowToastEvent";

const FAKE_STR = `fake-id`;
let timerStartValue = 0;
let timerEndValue = 0;

const _generateFakeId = () => FAKE_STR + Math.random();

const _deleteFakeId = (arg) => {
	[].concat(arg).forEach(l => {
		if (!_isInvalid(l.Id) && l.Id.startsWith(FAKE_STR)) delete l.Id;
	});
};

const _isFakeId = (Id) => _isInvalid(Id) ? false : Id.startsWith(FAKE_STR);
/**
 * Right align in LWC input works just after this
 */
const _applyDecStyle = () => {
	const inputAlignCenter = document.createElement('style');
	inputAlignCenter.innerText = `.dec input{ text-align: right!important; padding-left: 3px!important; padding-right: 3px!important }`;
	document.body.appendChild(inputAlignCenter);
};

/**
 * Method to put comments in a browser console
 * @param  message console log text
 * @param  color console log color
 */
const _cl = (message, color) => {
	try {
		message = typeof message === `object` ? message.toString() : message;
		console.log(
			`%c🌩️ ${message}`,
			`color:${color}; font: 1 Tahoma; font-size: 1.2em; font-weight: bolder; padding: 2px;`
		);
	} catch (e) {
		console.error(e);
	}
};

/**
 * Salesforce alert
 * @param type = error || warning || success || info
 * @param message = "BLM : Some Error"
 * @param title = "Toast Header" (not mandatory)
 * EXAMPLE:    _message('error', `Reporting : Generate Report Lines Error: ${e}`, 'Error');
 */
const _message = (type, message, title) => {
	try {
		dispatchEvent(new ShowToastEvent({
			title: type === 'error' ? `Error` : (title ? title : `Note`),
			message: message,
			variant: type,
			mode: type === 'error' ? 'sticky' : 'dismissible'
		}));
	} catch (e) {
		alert('Message Error : ' + e);
	}
};

const _isInvalid = (t) => {
	return (t === undefined || !t || t === 'undefined');
};

const _isInvalidNumber = (t) => {
	return (t === undefined || t === null || t === "" || isNaN(t));
};

const _reduceErrors = (errors) => {
	if (!Array.isArray(errors)) {
		errors = [errors];
	}

	return (
		errors
			// Remove null/undefined items
			.filter((error) => !!error)
			// Extract an error message
			.map((error) => {
				// UI API read errors
				if (Array.isArray(error.body)) {
					return error.body.map((e) => e.message);
				}
				// Page level errors
				else if (
					error?.body?.pageErrors &&
					error.body.pageErrors.length > 0
				) {
					return error.body.pageErrors.map((e) => e.message);
				}
				// Field level errors
				else if (
					error?.body?.fieldErrors &&
					Object.keys(error.body.fieldErrors).length > 0
				) {
					const fieldErrors = [];
					Object.values(error.body.fieldErrors).forEach(
						(errorArray) => {
							fieldErrors.push(
								...errorArray.map((e) => e.message)
							);
						}
					);
					return fieldErrors;
				}
				// UI API DML page level errors
				else if (
					error?.body?.output?.errors &&
					error.body.output.errors.length > 0
				) {
					return error.body.output.errors.map((e) => e.message);
				}
				// UI API DML field level errors
				else if (
					error?.body?.output?.fieldErrors &&
					Object.keys(error.body.output.fieldErrors).length > 0
				) {
					const fieldErrors = [];
					Object.values(error.body.output.fieldErrors).forEach(
						(errorArray) => {
							fieldErrors.push(
								...errorArray.map((e) => e.message)
							);
						}
					);
					return fieldErrors;
				}
				// UI API DML, Apex and network errors
				else if (error.body && typeof error.body.message === 'string') {
					return error.body.message;
				}
				// JS errors
				else if (typeof error.message === 'string') {
					return error.message;
				}
				// Unknown error shape so try HTTP status text
				return error.statusText;
			})
			// Flatten
			.reduce((prev, curr) => prev.concat(curr), [])
			// Remove empty strings
			.filter((message) => !!message)
	);
};

const _getCopy = (t, deleteId) => {
	if (_isInvalid(t)) return null;
	let r = JSON.parse(JSON.stringify(t));
	if (deleteId) {
		[].concat(r).forEach(l => delete l.Id);
	}
	return r;
};

/**
 * Method to put server error in toast
 * @param {*} reason reason
 * @param {*} error error
 */
const _parseServerError = (reason, error) => {
	console.log("Console log: " + JSON.stringify(error));
	let styleCSS = document.createElement("style");
	styleCSS.type = "text/css";
	styleCSS.innerHTML = " .toastMessage.forceActionsText{white-space : pre-line !important;}", "";
	document.getElementsByTagName("head")[0].appendChild(styleCSS);
	try {
		const event = new ShowToastEvent({
			title: reason ? reason : "Unknown",
			message: error.body ? "Status: " + error.status + "\nMessage: " + error?.body.message + "\nStack: " + error?.body.stackTrace : 'Unknown',
			variant: "error",
			mode: "sticky"
		});
		dispatchEvent(event);
	} catch (e) {
		alert('Parse Server Error : ' + e);
	}
};

const _getSOFromObject = (obj) => {
	if (!obj || Object.keys(obj).length === 0) return [];
	return Object.keys(obj).reduce((r, id) => {
		r.push({value: id, label: obj[id]});
		return r;
	}, []);
};

const _setCell = (cell, value, fill, font, numFmt, alignment, border) => {
	cell.value = value;
	cell.fill = fill;
	cell.font = font;
	cell.numFmt = numFmt;
	cell.alignment = alignment;
	cell.border = border;
};

export {
	_generateFakeId,
	_isFakeId,
	_deleteFakeId,
	_applyDecStyle,
	_cl,
	_message,
	_isInvalid,
	_isInvalidNumber,
	_reduceErrors,
	_getCopy,
	_parseServerError,
	_setCell,
	_getSOFromObject
};