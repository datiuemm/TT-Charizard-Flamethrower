#include <iostream>
#include <fstream>
#include <string>
#include <vector>
#include <sstream>
#include <map>

using namespace std;

string generate_initial_block(const string& filename, const string& array_name, int bit_width = 0) {
    ifstream infile(filename);
    if (!infile.is_open()) {
        cerr << "Could not open " << filename << endl;
        return "";
    }

    stringstream ss;
    string token;
    int index = 0;
    while (infile >> token) {
        if (token == "x" || token == "X") {
            ss << "    " << array_name << "[" << index << "] = " << (bit_width > 0 ? to_string(bit_width) + "'hx;" : "'hx;") << "\n";
        } else {
            ss << "    " << array_name << "[" << index << "] = " << (bit_width > 0 ? to_string(bit_width) + "'h" + token + ";" : "'h" + token + ";") << "\n";
        }
        index++;
    }
    return ss.str();
}

int main() {
    // You can change the input and output file names here
    ifstream infile("src/tt_um_a1k0n_nyancat.v");
    ofstream outfile("src/tt_um_a1k0n_nyancat.v.new");
    
    if (!infile.is_open() || !outfile.is_open()) {
        cerr << "Error opening verilog files" << endl;
        return 1;
    }

    string line;
    while (getline(infile, line)) {
        if (line.find("$readmemh") != string::npos) {
            // parse $readmemh("../data/palette_r.hex", palette_r);
            size_t start_quote = line.find("\"");
            size_t end_quote = line.find("\"", start_quote + 1);
            size_t comma = line.find(",", end_quote);
            size_t end_paren = line.find(")", comma);
            
            if (start_quote != string::npos && end_quote != string::npos && comma != string::npos && end_paren != string::npos) {
                string hex_file = line.substr(start_quote + 1, end_quote - start_quote - 1);
                // remove ../ from hex_file
                if (hex_file.substr(0, 3) == "../") hex_file = hex_file.substr(3);
                
                string array_name = line.substr(comma + 1, end_paren - comma - 1);
                // trim whitespace
                size_t first = array_name.find_first_not_of(" \t");
                size_t last = array_name.find_last_not_of(" \t");
                if (first != string::npos && last != string::npos) {
                    array_name = array_name.substr(first, (last - first + 1));
                }
                
                cout << "Replacing " << hex_file << " into " << array_name << endl;
                
                outfile << generate_initial_block(hex_file, array_name);
            }
        } else {
            outfile << line << "\n";
        }
    }

    infile.close();
    outfile.close();

    cout << "Done! The output is saved to src/tt_um_a1k0n_nyancat.v.new" << endl;
    return 0;
}
