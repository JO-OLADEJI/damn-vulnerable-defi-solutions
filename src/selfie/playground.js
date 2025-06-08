// const phrase = "you can purchase #3 #4 and 7# items";
const phrase = "2 3 #5 6 #8 #10 11 12# #15 #20#";
const reduction = 75;

const solution = () => {
    const result = [];
    const words = phrase.split(" ");

    // console.log(words);
    for (let x of words) {
        if (x.startsWith("#") && /^\#\d+$/.test(x)) {
            let value = parseFloat(x.slice(1));
            const remainder = (1 - reduction / 100) * value;
            result.push(`#${remainder.toFixed(2)}`);
        } else {
            result.push(x);
        }
    }

    return result.join(" ");
};

console.log(solution());
