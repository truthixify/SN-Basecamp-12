"use client";

import { ConnectedAddress } from "~~/components/ConnectedAddress";
import { useState } from "react";
import { useScaffoldReadContract } from "~~/hooks/scaffold-stark/useScaffoldReadContract";
// import { useScaffoldWriteContract } from "~~/hooks/scaffold-stark/useScaffoldWriteContract";
import { useScaffoldMultiWriteContract } from "~~/hooks/scaffold-stark/useScaffoldMultiWriteContract";
// import { useScaffoldEventHistory } from "~~/hooks/scaffold-stark/useScaffoldEventHistory";
import { useBlockNumber } from "@starknet-react/core";
// import { useDeployedContractInfo } from "~~/hooks/scaffold-stark/useDeployedContractInfo";
import { useTargetNetwork } from "~~/hooks/scaffold-stark/useTargetNetwork";
import { useDeployedContractInfo } from "~~/hooks/scaffold-stark";
import { inc } from "nprogress";
import { useScaffoldWriteContract } from "~~/hooks/scaffold-stark/useScaffoldWriteContract";
import { useScaffoldEventHistory } from "~~/hooks/scaffold-stark/useScaffoldEventHistory";

const Home = () => {
  const [inputAmount, setInputAmount] = useState<string>("");

  const { data: counter } = useDeployedContractInfo("Counter");

  const { targetNetwork } = useTargetNetwork();
  const { data: counterValue } = useScaffoldReadContract({
    contractName: "Counter",
    functionName: "get_counter",    
  });

  const { data: contractBalance } = useScaffoldReadContract({
    contractName: "Strk",
    functionName: "balance_of",
    args: [counter?.address],
  });

  const formattedBalance = contractBalance ? (Number(contractBalance) / 1e18).toFixed(6) : "0.000000";

  const {data: winNumber} = useScaffoldReadContract({
    contractName: "Counter",
    functionName: "get_win_number",
  });

  const {data: blockNumber} = useBlockNumber()

  const {data: events} = useScaffoldEventHistory({
    contractName: "Counter",
    eventName: "contracts::counter::Counter::Increased",
    fromBlock: blockNumber ? (blockNumber > 50n ? BigInt(blockNumber - 50) : 0n) : 0n,
    watch: true,
  })

  const {sendAsync: incrementCounter} = useScaffoldWriteContract({
    contractName: "Counter",
    functionName: "increase_counter",
  })

  const {sendAsync: incrementWithStrkDeposit} = useScaffoldMultiWriteContract({
    calls: [
        {
            contractName: "Strk",
            functionName: "transfer",
            args: [counter?.address, BigInt(Number(inputAmount) * 10 ** 18)],
        }, 
        {
            contractName: "Counter",
            functionName: "increase_counter",
        }
    ]
  })

  const handleIncrement = () => {
    if (inputAmount && parseFloat(inputAmount) > 0) {
      incrementWithStrkDeposit();
    }

    incrementCounter()
  }
  
  return (
    <div className="flex items-center flex-col flex-grow pt-10">
      <div className="px-5 w-full max-w-6xl">
        <h1 className="text-center mb-8">
          <span className="block text-4xl font-bold bg-gradient-to-r from-primary to-secondary bg-clip-text text-transparent">
            Counter Workshop
          </span>
          <div className="flex justify-center">
            <span className="text-base mt-2 badge badge-primary">
              { targetNetwork.name }
            </span>
          </div>
        </h1>
        <ConnectedAddress />
        <div className="mt-8 space-y-6">
          <div className="bg-base-100 p-8 rounded-3xl border border-gradient shadow-lg">
            <h2 className="text-2xl font-bold mb-6 text-secondary">
              Counter Game
            </h2>
            <div className="p-4 bg-base-200 rounded-xl">
              <h3 className="text-lg font-semibold mb-2">Current Count</h3>
              <p className="text-5xl font-bold text-center my-4">
                {counterValue?.toString() ?? "0"}
                <span className="text-xl opacity-60 ml-2">/ {winNumber?.toString()}</span>
              </p>
              
              <div className="bg-base-300 p-4 rounded-lg my-4">
                <p className="text-xl font-medium text-center">
                  Prize Pool: {formattedBalance} STRK
                </p>
              </div>
              
              <div className="form-control mb-4">
                <label className="label">
                  <span className="label-text text-lg font-medium">
                    STRK Amount (Optional)
                  </span>
                </label>
                <div className="flex bg-base-300 p-2 rounded-lg">
                  <input
                    type="number"
                    className="input input-ghost focus:outline-none h-[2.5rem] min-h-[2.5rem] px-4 w-full"
                    value={inputAmount}
                    onChange={(e) => setInputAmount(e.target.value)}
                    placeholder="Enter amount to send with increment"
                    step="0.01"
                    min="0"
                  />
                </div>
              </div>
              
              <div className="flex justify-center gap-4 mt-4">
                <button
                  className="btn btn-primary btn-lg"
                  onClick={handleIncrement}
                >
                  {inputAmount && parseFloat(inputAmount) > 0
                    ? `Increment + Send ${inputAmount} STRK`
                    : "Increment"}
                </button>
                <button
                  className="btn btn-outline btn-lg"
                  onClick={() => console.log("Reset clicked")}
                >
                  Reset (costs {formattedBalance} STRK)
                </button>
              </div>
            </div>
          </div>
          
          <div className="bg-base-100 p-8 rounded-3xl border border-gradient shadow-lg">
            <h2 className="text-2xl font-bold mb-6 text-secondary">
              Activity History
            </h2>
            <div className="space-y-4">
              {events && events.length > 0 ? (
                events.map((event, index) => (
                  <div key={index} className="bg-base-200 p-4 rounded-xl">
                    <p className="text-lg">
                      <span className="font-medium">{ event.parsedArgs.account.substring(0, 6) }</span>
                    </p>
                  </div>
                ))
              ) : (
                <p className="text-center text-lg opacity-70">No activity yet</p>
              )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};

export default Home;