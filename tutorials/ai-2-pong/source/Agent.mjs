
import { Brain } from './Brain.mjs';



const BRAIN_REFERENCE = {
	inputs: [
		0,   0.5, // paddle position
		0,   0.8, // ball position
		0.5, 0.2  // ball speed (1.0 == 25px/frame)
	],
	outputs: [
		0.8 // targeted y position
	]
};



const Agent = function() {

	this.brain  = new Brain();


	// XXX: Brain needs a reference dataset
	this.brain.initialize(
		BRAIN_REFERENCE.inputs,
		BRAIN_REFERENCE.outputs
	);

};

Agent.prototype = {

	compute: function(inputs) {
		return this.brain.compute(inputs);
	},

	learn: function(inputs, outputs) {
		return this.brain.learn(inputs, outputs);
	},

	clone: function() {

		let clone = new Agent();

		// This will copy/paste the exact same Brain
		// onto our clone. We need this method for
		// having non-linked properties, in case
		// this implementation is reused in an
		// Evolutionary algorithm.

		clone.brain.layers = JSON.parse(JSON.stringify(this.brain.layers));


		return clone;

	}

};


export { Agent };

